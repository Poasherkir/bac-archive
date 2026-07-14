import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam.dart';

/// Reads the exam manifest from Supabase (anon key, public SELECT via RLS).
class ExamRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// The full manifest for [stream], newest year first. Rows are matched on
  /// the `streams` array so entries shared between streams appear in each.
  Future<List<Exam>> fetchManifest(String stream) async {
    final rows = await _db
        .from('exams')
        .select()
        .contains('streams', [stream])
        .order('year', ascending: false);

    return (rows as List)
        .map((r) => Exam.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }
}
