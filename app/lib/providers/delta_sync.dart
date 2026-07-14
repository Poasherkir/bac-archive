import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'manifest_providers.dart';
import 'providers.dart';

/// Runs the silent, no-UI background sync once per app session (on Home mount).
/// If offline, it does nothing and the app keeps working from local storage.
class DeltaSync {
  DeltaSync(this._ref);
  final Ref _ref;
  bool _started = false;

  Future<void> maybeRun() async {
    if (_started) return;
    _started = true;

    if (!AppConfig.isConfigured) return;

    try {
      final results =
          await _ref.read(connectivityProvider).checkConnectivity();
      final offline =
          results.isEmpty || results.every((c) => c == ConnectivityResult.none);
      if (offline) return; // work from local storage, no check

      final service = _ref.read(syncServiceProvider);
      final plan = await service.buildPlan();

      // Large top-ups (e.g. new streams after an update) wait for Wi-Fi;
      // small day-to-day deltas may use mobile data.
      const bigDeltaBytes = 30 * 1024 * 1024;
      final unmetered = results.any((c) =>
          c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet);
      if (!unmetered && plan.pendingBytes > bigDeltaBytes) {
        debugPrint('Delta sync deferred to Wi-Fi '
            '(${plan.pendingBytes} bytes pending)');
        return;
      }

      final changed = await service.syncFromPlan(plan);
      if (changed) {
        // New/updated content arrived — refresh the offline manifest views.
        _ref.invalidate(allManifestProvider);
      }
    } catch (e) {
      // Silent: background sync never interrupts browsing.
      debugPrint('Delta sync skipped: $e');
    }
  }
}

final deltaSyncProvider = Provider<DeltaSync>((ref) => DeltaSync(ref));
