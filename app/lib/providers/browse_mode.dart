import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

const _kBrowseModeKey = 'browse_mode';

/// Home browsing entry point: by year (default) or by subject.
enum BrowseMode { byYear, bySubject }

/// Persisted last-used browse mode.
class BrowseModeController extends Notifier<BrowseMode> {
  @override
  BrowseMode build() {
    final stored =
        ref.read(sharedPreferencesProvider).getString(_kBrowseModeKey);
    return stored == 'subject' ? BrowseMode.bySubject : BrowseMode.byYear;
  }

  Future<void> set(BrowseMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(
          _kBrowseModeKey,
          mode == BrowseMode.bySubject ? 'subject' : 'year',
        );
  }
}

final browseModeProvider =
    NotifierProvider<BrowseModeController, BrowseMode>(
        BrowseModeController.new);
