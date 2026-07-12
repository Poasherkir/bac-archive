// Unit tests for the Exam model + config invariants.
// (A full widget test needs Supabase init + network fonts, so we keep the
//  automated test at the pure-Dart layer where it's fast and reliable.)

import 'package:flutter_test/flutter_test.dart';

import 'package:bacsci/config/app_config.dart';
import 'package:bacsci/models/exam.dart';

void main() {
  group('Exam.fromMap', () {
    test('parses a full row', () {
      final exam = Exam.fromMap({
        'id': 'abc',
        'year': 2024,
        'stream': 'علوم تجريبية',
        'subject': 'رياضيات',
        'sujet_url': 'https://x/sujet.pdf',
        'solution_url': null,
        'correction_url': 'https://x/correction.pdf',
        'file_size_bytes': 1234,
      });

      expect(exam.year, '2024'); // coerced to String
      expect(exam.subject, 'رياضيات');
      expect(exam.fileSizeBytes, 1234);
      expect(exam.hasAnyFile, isTrue);
    });

    test('availableFiles skips null urls', () {
      final exam = Exam.fromMap({
        'id': 'abc',
        'year': '2023',
        'stream': 'علوم تجريبية',
        'subject': 'فيزياء',
        'sujet_url': 'https://x/sujet.pdf',
        'solution_url': null,
        'correction_url': null,
        'file_size_bytes': 0,
      });

      final kinds = exam.availableFiles.map((f) => f.kind).toList();
      expect(kinds, [ExamFileKind.sujet]);
    });
  });

  test('subject list + file kinds are the expected size', () {
    expect(kSubjects.length, 9);
    expect(ExamFileKind.values.length, 3);
  });
}
