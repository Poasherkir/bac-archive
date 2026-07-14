import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'providers.dart';

const _kStreamKey = 'selected_stream';

/// The stream the student picked (label), or null if never chosen.
/// Null happens only on fresh installs that predate the picker — existing
/// synced users default to علوم تجريبية for full backward compatibility.
class SelectedStreamController extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(sharedPreferencesProvider).getString(_kStreamKey);

  Future<void> set(String label) async {
    state = label;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kStreamKey, label);
  }
}

final selectedStreamProvider =
    NotifierProvider<SelectedStreamController, String?>(
        SelectedStreamController.new);

/// The stream label everything operates on (falls back to علوم تجريبية).
final activeStreamProvider = Provider<String>(
  (ref) => ref.watch(selectedStreamProvider) ?? kStreams.first.label,
);

/// Slug of the active stream (per-stream local flags/manifest files).
final activeStreamSlugProvider = Provider<String>((ref) {
  final label = ref.watch(activeStreamProvider);
  return kStreams
      .firstWhere((s) => s.label == label, orElse: () => kStreams.first)
      .slug;
});

/// Subjects browsed under the active stream.
final activeSubjectsProvider = Provider<List<Subject>>(
  (ref) => subjectsForStream(ref.watch(activeStreamProvider)),
);
