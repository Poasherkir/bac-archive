import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/exam.dart';
import 'providers.dart';

/// The cached manifest, read from local storage. This is the ONLY source the
/// browsing screens use — no network calls to view anything.
final manifestProvider = FutureProvider<List<Exam>>((ref) async {
  return ref.watch(localStoreProvider).readManifest();
});

/// Distinct years present in the archive, newest first.
final yearsProvider = FutureProvider<List<String>>((ref) async {
  final exams = await ref.watch(manifestProvider.future);
  final years = exams.map((e) => e.year).toSet().toList()
    ..sort((a, b) => b.compareTo(a)); // 4-digit strings sort like numbers
  return years;
});

/// The exam row for a given (year, subject), or null if none exists.
final examProvider =
    FutureProvider.family<Exam?, ({String year, String subject})>(
        (ref, key) async {
  final exams = await ref.watch(manifestProvider.future);
  for (final e in exams) {
    if (e.year == key.year && e.subject == key.subject) return e;
  }
  return null;
});

/// Which file kinds for a (year, subject) are actually present on disk.
/// Drives enabled/disabled state of the three buttons on the Subject screen.
final subjectAvailabilityProvider =
    FutureProvider.family<Set<ExamFileKind>, ({String year, String subject})>(
        (ref, key) async {
  final exam = await ref.watch(examProvider(key).future);
  if (exam == null) return <ExamFileKind>{};

  final store = ref.watch(localStoreProvider);
  final available = <ExamFileKind>{};
  for (final file in exam.availableFiles) {
    if (await store.existsForUrl(file.url)) available.add(file.kind);
  }
  return available;
});

/// Subjects (of the fixed 9) that have at least one entry row for [year].
/// Used to dim subject cards with no content yet.
final subjectsWithContentProvider =
    FutureProvider.family<Set<String>, String>((ref, year) async {
  final exams = await ref.watch(manifestProvider.future);
  return exams
      .where((e) => e.year == year && e.hasAnyFile)
      .map((e) => e.subject)
      .toSet();
});

/// Convenience: the fixed subject list this app browses.
const kBrowseSubjects = kSubjects;
