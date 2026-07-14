import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam.dart';

/// Reads the exam manifest from Supabase (anon key, public SELECT via RLS).
class ExamRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// The full manifest — every stream, newest year first. All streams are
  /// downloaded up front; the UI filters by the selected stream locally.
  Future<List<Exam>> fetchManifest() async {
    final rows = await _db
        .from('exams')
        .select()
        .order('year', ascending: false);

    return (rows as List)
        .map((r) => Exam.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }
}
