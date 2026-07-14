import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bacsci/models/exam.dart';
import 'package:bacsci/services/downloader.dart';
import 'package:bacsci/services/exam_repository.dart';
import 'package:bacsci/services/local_store.dart';
import 'package:bacsci/services/sync_service.dart';

/// Repo that returns a fixed manifest (no Supabase).
class _FakeRepo extends ExamRepository {
  _FakeRepo(this.list);
  final List<Exam> list;
  @override
  Future<List<Exam>> fetchManifest() async => list;
}

/// Downloader that just writes a stub file (no network).
class _FakeDownloader extends Downloader {
  int calls = 0;
  @override
  Future<void> download(
    String url,
    String destPath, {
    void Function(int chunkBytes)? onBytes,
    bool Function()? isCancelled,
  }) async {
    if (await File(destPath).exists()) return;
    calls++;
    final f = File(destPath);
    await f.parent.create(recursive: true);
    await f.writeAsString('%PDF-stub');
  }
}

/// LocalStore rooted at a temp dir (no path_provider).
class _TmpStore extends LocalStore {
  _TmpStore(super.prefs, this._dir);
  final Directory _dir;
  @override
  Future<Directory> baseDir() async => _dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _TmpStore store;
  late _FakeDownloader downloader;

  Exam exam(String year) => Exam(
        id: 'id-$year',
        year: year,
        stream: 'علوم تجريبية',
        subject: 'رياضيات',
        sujetUrl:
            'https://ref.supabase.co/storage/v1/object/public/bac-files/$year/sciences/maths/sujet.pdf',
        fileSizeBytes: 100,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('bacsci_test');
    store = _TmpStore(await SharedPreferences.getInstance(), tmp);
    downloader = _FakeDownloader();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  SyncService service(List<Exam> manifest) => SyncService(
        repo: _FakeRepo(manifest),
        store: store,
        downloader: downloader,
      );

  test('first delta-sync downloads missing files and reports change', () async {
    final changed = await service([exam('2024')]).runDeltaSync();
    expect(changed, isTrue);
    expect(downloader.calls, 1);
    // manifest cached for offline Home
    expect((await store.readManifest('all')).length, 1);
    // file mirrored on disk
    expect(await store.existsForUrl(exam('2024').sujetUrl!), isTrue);
  });

  test('second delta-sync with no changes reports no change', () async {
    await service([exam('2024')]).runDeltaSync();
    downloader.calls = 0;

    final changed = await service([exam('2024')]).runDeltaSync();
    expect(changed, isFalse);
    expect(downloader.calls, 0);
  });

  test('a new row on next sync is detected and downloaded', () async {
    await service([exam('2024')]).runDeltaSync();
    downloader.calls = 0;

    final changed =
        await service([exam('2024'), exam('2023')]).runDeltaSync();
    expect(changed, isTrue);
    expect(downloader.calls, 1); // only the new file
    expect((await store.readManifest('all')).length, 2);
  });
}
