/// App-wide configuration and constants.
///
/// The Supabase anon key is PUBLIC by design (RLS controls access) and is
/// expected to ship inside the APK. Never place the service_role key here.
///
/// You can override these at build time without editing the file:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
library;

class AppConfig {
  AppConfig._();

  // --- Supabase --------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gqaqazavimhbseawivjf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxYXFhemF2aW1oYnNlYXdpdmpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3ODg4NTUsImV4cCI6MjA5OTM2NDg1NX0.HlWSQOyL1sRZFKFCS5LhDLOzRIyJ_ia7ECqJw6OR-5A',
  );

  static const String storageBucket = 'bac-files';

  /// The single stream this app is dedicated to (V1).
  static const String stream = 'علوم تجريبية';

  /// Tagline shown on Home.
  static const String tagline = 'أرشيف مواضيع البكالوريا — شعبة علوم تجريبية';

  static const String appTitle = 'أرشيف البكالوريا';

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR-PROJECT-REF') &&
      !supabaseAnonKey.contains('YOUR-ANON-PUBLIC-KEY');
}

/// One selectable subject: Arabic display label + English storage-path slug.
/// MUST stay in sync with admin/constants.js and supabase/migration.sql.
class Subject {
  const Subject(this.label, this.slug);
  final String label;
  final String slug;
}

const List<Subject> kSubjects = [
  Subject('رياضيات', 'maths'),
  Subject('فيزياء', 'physique'),
  Subject('علوم طبيعية', 'svt'),
  Subject('عربية', 'arabe'),
  Subject('فرنسية', 'francais'),
  Subject('إنجليزية', 'anglais'),
  Subject('فلسفة', 'philo'),
  Subject('تاريخ وجغرافيا', 'histoire-geo'),
  Subject('تربية إسلامية', 'islamique'),
];

/// The three file kinds per (year, subject) entry.
enum ExamFileKind {
  sujet('الموضوع', 'sujet.pdf'),
  solution('الحل', 'solution.pdf'),
  correction('الحل النموذجي', 'correction.pdf');

  const ExamFileKind(this.label, this.filename);
  final String label;
  final String filename;
}
