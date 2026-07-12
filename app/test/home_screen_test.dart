import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bacsci/models/exam.dart';
import 'package:bacsci/providers/manifest_providers.dart';
import 'package:bacsci/screens/home_screen.dart';
import 'package:bacsci/widgets/year_card.dart';

Exam _exam(String year, String subject) => Exam(
      id: '$year-$subject',
      year: year,
      stream: 'علوم تجريبية',
      subject: subject,
      sujetUrl: 'https://x/public/bac-files/$year/sciences/maths/sujet.pdf',
      fileSizeBytes: 1000,
    );

Widget _app(List<Exam> manifest) => ProviderScope(
      overrides: [
        manifestProvider.overrideWith((ref) async => manifest),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      ),
    );

void main() {
  testWidgets('renders one card per distinct year, newest first with badge',
      (tester) async {
    await tester.pumpWidget(_app([
      _exam('2022', 'رياضيات'),
      _exam('2024', 'رياضيات'),
      _exam('2024', 'فيزياء'), // same year, should not duplicate
      _exam('2023', 'رياضيات'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(YearCard), findsNWidgets(3));
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('2023'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    // Latest year (2024 here) carries the "الأحدث" badge — exactly one.
    expect(find.text('الأحدث'), findsOneWidget);
  });

  testWidgets('search filters the year grid', (tester) async {
    await tester.pumpWidget(_app([
      _exam('2024', 'رياضيات'),
      _exam('2023', 'رياضيات'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), '2024');
    await tester.pumpAndSettle();

    // The 2024 card remains (target the Card, not the search field's text).
    expect(find.widgetWithText(Card, '2024'), findsOneWidget);
    // The 2023 card is filtered out.
    expect(find.widgetWithText(Card, '2023'), findsNothing);
  });

  testWidgets('shows empty state when manifest is empty', (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد محتوى بعد.'), findsOneWidget);
  });
}
