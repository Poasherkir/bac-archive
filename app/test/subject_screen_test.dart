import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bacsci/models/exam.dart';
import 'package:bacsci/providers/manifest_providers.dart';
import 'package:bacsci/providers/providers.dart';
import 'package:bacsci/screens/subject_screen.dart';
import 'package:bacsci/services/local_store.dart';

/// LocalStore whose files "exist" (avoids path_provider).
class _FakeStore extends LocalStore {
  _FakeStore(super.prefs);
  @override
  Future<bool> existsForUrl(String url) async => true;
  @override
  Future<String> localPathForUrl(String url) async => '/tmp/x.pdf';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('subject screen renders 3 buttons for an entry with files',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final exam = Exam(
      id: '2008-physique',
      year: '2008',
      stream: 'علوم تجريبية',
      subject: 'فيزياء',
      sujetUrl: 'https://x/public/bac-files/2008/sciences/physique/sujet.pdf',
      solutionUrl:
          'https://x/public/bac-files/2008/sciences/physique/solution.pdf',
      fileSizeBytes: 1000,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        manifestProvider.overrideWith((ref) async => [exam]),
        localStoreProvider.overrideWith((ref) => _FakeStore(prefs)),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SubjectScreen(year: '2008', subject: 'فيزياء'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الموضوع'), findsOneWidget);
    expect(find.text('الحل'), findsOneWidget);
    expect(find.text('الحل النموذجي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
