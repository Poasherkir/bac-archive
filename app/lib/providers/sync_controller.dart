import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/downloader.dart';
import '../services/sync_service.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Sync state machine (first-launch "Preparing Content" flow).
// ---------------------------------------------------------------------------
sealed class SyncState {
  const SyncState();
}

class SyncInitial extends SyncState {
  const SyncInitial();
}

/// Fetching the manifest / deciding what to do.
class SyncChecking extends SyncState {
  const SyncChecking();
}

/// On mobile data — ask before downloading [totalBytes] across [fileCount] files.
class SyncNeedWifiConfirm extends SyncState {
  const SyncNeedWifiConfirm(this.totalBytes, this.fileCount);
  final int totalBytes;
  final int fileCount;
}

/// User chose to wait for Wi-Fi.
class SyncWaitingWifi extends SyncState {
  const SyncWaitingWifi();
}

class SyncDownloading extends SyncState {
  const SyncDownloading({
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
  });

  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;

  double get progress =>
      bytesTotal <= 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);
}

class SyncOfflineState extends SyncState {
  const SyncOfflineState();
}

class SyncErrorState extends SyncState {
  const SyncErrorState(this.message);
  final String message;
}

class SyncDone extends SyncState {
  const SyncDone();
}

// ---------------------------------------------------------------------------
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncInitial();

  bool _cancelled = false;
  SyncPlan? _plan;

  /// Entry point from the sync screen. Skips straight to done if a previous
  /// sync already completed.
  Future<void> begin() async {
    if (ref.read(localStoreProvider).isSyncComplete) {
      state = const SyncDone();
      return;
    }
    await start();
  }

  Future<void> start() async {
    _cancelled = false;
    state = const SyncChecking();
    try {
      if (!AppConfig.isConfigured) {
        state = const SyncErrorState(
          'لم يتم إعداد الاتصال بالخادم. يرجى المحاولة لاحقًا.',
        );
        return;
      }

      final results = await ref.read(connectivityProvider).checkConnectivity();
      if (_isOffline(results)) {
        state = const SyncOfflineState();
        return;
      }

      final plan = await ref.read(syncServiceProvider).buildPlan();
      _plan = plan;

      if (plan.isUpToDate) {
        await _finish(plan);
        return;
      }

      // On mobile data, confirm before downloading.
      if (!_isUnmetered(results)) {
        state = SyncNeedWifiConfirm(plan.pendingBytes, plan.pending.length);
        return;
      }

      await _download(plan);
    } catch (e) {
      state = SyncErrorState(_friendly(e));
    }
  }

  /// Proceed with download despite being on mobile data.
  Future<void> continueAnyway() async {
    final plan = _plan;
    if (plan == null) {
      await start();
      return;
    }
    try {
      await _download(plan);
    } catch (e) {
      state = SyncErrorState(_friendly(e));
    }
  }

  void waitForWifi() => state = const SyncWaitingWifi();

  Future<void> retry() => start();

  void cancel() => _cancelled = true;

  Future<void> _download(SyncPlan plan) async {
    _cancelled = false;
    final total = plan.pending.length;
    var done = 0;
    var bytes = 0;

    state = SyncDownloading(
      filesDone: 0,
      filesTotal: total,
      bytesDone: 0,
      bytesTotal: plan.pendingBytes,
    );

    final downloader = ref.read(downloaderProvider);
    for (final item in plan.pending) {
      if (_cancelled) return;
      await downloader.download(
        item.url,
        item.localPath,
        isCancelled: () => _cancelled,
        onBytes: (n) {
          bytes += n;
          state = SyncDownloading(
            filesDone: done,
            filesTotal: total,
            bytesDone: bytes,
            bytesTotal: plan.pendingBytes,
          );
        },
      );
      done++;
      state = SyncDownloading(
        filesDone: done,
        filesTotal: total,
        bytesDone: bytes,
        bytesTotal: plan.pendingBytes,
      );
    }

    await _finish(plan);
  }

  Future<void> _finish(SyncPlan plan) async {
    final store = ref.read(localStoreProvider);
    await store.saveManifest(plan.manifest);
    await store.setSyncComplete(true);
    state = const SyncDone();
  }

  bool _isOffline(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((c) => c == ConnectivityResult.none);

  bool _isUnmetered(List<ConnectivityResult> r) => r.any(
        (c) => c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet,
      );

  String _friendly(Object e) => e is SyncCancelled
      ? 'تم إيقاف التحميل.'
      : 'تعذّر تحميل المحتوى. تحقق من اتصالك بالإنترنت وحاول مجددًا.';
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
