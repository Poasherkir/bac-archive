import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/downloader.dart';
import '../services/exam_repository.dart';
import '../services/local_store.dart';
import '../services/sync_service.dart';

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

final examRepositoryProvider = Provider<ExamRepository>((ref) => ExamRepository());

final downloaderProvider = Provider<Downloader>((ref) => Downloader());

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    repo: ref.watch(examRepositoryProvider),
    store: ref.watch(localStoreProvider),
    downloader: ref.watch(downloaderProvider),
  ),
);
