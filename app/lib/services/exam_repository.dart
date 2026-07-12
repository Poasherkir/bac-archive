import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/exam.dart';

/// Reads the exam manifest from Supabase (anon key, public SELECT via RLS).
class ExamRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// The full manifest for this stream, newest year first.
  Future<List<Exam>> fetchManifest() async {
    final rows = await _db
        .from('exams')
        .select()
        .eq('stream', AppConfig.stream)
        .order('year', ascending: false);

    return (rows as List)
        .map((r) => Exam.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }
}
