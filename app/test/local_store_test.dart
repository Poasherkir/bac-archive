import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bacsci/services/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
  });

  group('relativePathForUrl mirrors storage layout', () {
    test('standard public URL', () {
      const url =
          'https://ref.supabase.co/storage/v1/object/public/bac-files/2024/sciences/maths/sujet.pdf';
      expect(store.relativePathForUrl(url), '2024/sciences/maths/sujet.pdf');
    });

    test('strips query string (cache-busting token)', () {
      const url =
          'https://ref.supabase.co/storage/v1/object/public/bac-files/2023/sciences/svt/correction.pdf?t=123';
      expect(
        store.relativePathForUrl(url),
        '2023/sciences/svt/correction.pdf',
      );
    });

    test('decodes percent-encoded segments', () {
      const url =
          'https://ref.supabase.co/storage/v1/object/public/bac-files/2022/sciences/histoire-geo/solution.pdf';
      expect(
        store.relativePathForUrl(url),
        '2022/sciences/histoire-geo/solution.pdf',
      );
    });
  });

  group('sync flag', () {
    test('per-stream flags persist independently', () async {
      expect(store.isSyncCompleteFor('sci'), isFalse);
      await store.setSyncCompleteFor('sci');
      expect(store.isSyncCompleteFor('sci'), isTrue);
      expect(store.isSyncCompleteFor('math'), isFalse);
    });

    test('legacy flag counts as sciences', () async {
      SharedPreferences.setMockInitialValues({'sync_complete': true});
      final legacy = LocalStore(await SharedPreferences.getInstance());
      expect(legacy.isSyncCompleteFor('sci'), isTrue);
      expect(legacy.isSyncCompleteFor('math'), isFalse);
    });
  });
}
