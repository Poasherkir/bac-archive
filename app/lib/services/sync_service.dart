import 'dart:convert';
import 'dart:io';

import '../models/exam.dart';
import 'downloader.dart';
import 'exam_repository.dart';
import 'local_store.dart';

/// A single file that needs downloading.
class DownloadItem {
  const DownloadItem(this.url, this.localPath);
  final String url;
  final String localPath;
}

/// The result of comparing the remote manifest against local storage.
class SyncPlan {
  const SyncPlan({
    required this.manifest,
    required this.pending,
    required this.totalBytes,
    required this.pendingBytes,
  });

  final List<Exam> manifest;
  final List<DownloadItem> pending;

  /// Sum of file_size_bytes across the whole archive.
  final int totalBytes;

  /// Sum of file_size_bytes for rows that still have something to download.
  final int pendingBytes;

  bool get isUpToDate => pending.isEmpty;
}

/// Orchestrates offline sync: fetch manifest, diff against disk, download the
/// gap. Used by both first-launch sync (Step 5) and background delta-sync
/// (Step 7).
class SyncService {
  SyncService({
    required this.repo,
    required this.store,
    required this.downloader,
  });

  final ExamRepository repo;
  final LocalStore store;
  final Downloader downloader;

  /// Fetch the manifest for [stream] and compute what's missing locally.
  Future<SyncPlan> buildPlan(String stream) async {
    final manifest = await repo.fetchManifest(stream);
    final pending = <DownloadItem>[];
    var totalBytes = 0;
    var pendingBytes = 0;

    for (final exam in manifest) {
      totalBytes += exam.fileSizeBytes;
      var rowHasPending = false;
      for (final file in exam.availableFiles) {
        final path = await store.localPathForUrl(file.url);
        if (!await File(path).exists()) {
          pending.add(DownloadItem(file.url, path));
          rowHasPending = true;
        }
      }
      if (rowHasPending) pendingBytes += exam.fileSizeBytes;
    }

    return SyncPlan(
      manifest: manifest,
      pending: pending,
      totalBytes: totalBytes,
      pendingBytes: pendingBytes,
    );
  }

  /// Persist the manifest so Home works fully offline next launch.
  Future<void> commitManifest(String slug, List<Exam> manifest) =>
      store.saveManifest(slug, manifest);

  /// Silent background sync used on every launch after the first.
  /// Downloads any new files, refreshes the cached manifest, and reports
  /// whether anything visible changed (so the UI can refresh). Individual
  /// download failures are swallowed and retried on the next launch.
  Future<bool> runDeltaSync(
      {required String stream, required String slug}) async {
    final oldManifest = await store.readManifest(slug);
    final plan = await buildPlan(stream);

    var downloadedAny = false;
    for (final item in plan.pending) {
      try {
        await downloader.download(item.url, item.localPath);
        downloadedAny = true;
      } catch (_) {
        // Leave it for the next launch; don't abort the whole sync.
      }
    }

    await store.saveManifest(slug, plan.manifest);
    return downloadedAny || !_sameManifest(oldManifest, plan.manifest);
  }

  bool _sameManifest(List<Exam> a, List<Exam> b) {
    String encode(List<Exam> m) => jsonEncode(m.map((e) => e.toMap()).toList());
    return encode(a) == encode(b);
  }
}
