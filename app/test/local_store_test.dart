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
    test('defaults to false, then persists true', () async {
      expect(store.isSyncComplete, isFalse);
      await store.setSyncComplete(true);
      expect(store.isSyncComplete, isTrue);
    });
  });
}
