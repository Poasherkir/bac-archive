import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../screens/stream_picker_screen.dart';
import '../screens/sync_screen.dart';
import '../screens/home_screen.dart';
import '../screens/year_screen.dart';
import '../screens/subject_archive_screen.dart';
import '../screens/subject_screen.dart';
import '../screens/pdf_viewer_screen.dart';

/// Arguments passed to the PDF viewer via `extra`.
class PdfViewerArgs {
  const PdfViewerArgs({required this.filePath, required this.title});
  final String filePath;
  final String title;
}

GoRouter buildRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/stream',
      name: 'streamPicker',
      builder: (context, state) => const StreamPickerScreen(),
    ),
    GoRoute(
      path: '/sync',
      name: 'sync',
      builder: (context, state) => const SyncScreen(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/year/:year',
      name: 'year',
      builder: (context, state) =>
          YearScreen(year: state.pathParameters['year']!),
    ),
    GoRoute(
      // The path carries the ASCII subject SLUG (not the Arabic label), so no
      // percent-encoding is involved. We map it back to the display label here.
      path: '/year/:year/subject/:slug',
      name: 'subject',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final match = kAllSubjects.where((s) => s.slug == slug);
        final subject = match.isNotEmpty ? match.first.label : slug;
        return SubjectScreen(
          year: state.pathParameters['year']!,
          subject: subject,
        );
      },
    ),
    GoRoute(
      // Subject-first flow: all years for one subject.
      path: '/subject/:slug',
      name: 'subjectArchive',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final match = kAllSubjects.where((s) => s.slug == slug);
        final subject = match.isNotEmpty ? match.first.label : slug;
        return SubjectArchiveScreen(subject: subject);
      },
    ),
    GoRoute(
      path: '/viewer',
      name: 'viewer',
      builder: (context, state) {
        final args = state.extra as PdfViewerArgs;
        return PdfViewerScreen(filePath: args.filePath, title: args.title);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('صفحة غير موجودة: ${state.uri}')),
  ),
);

