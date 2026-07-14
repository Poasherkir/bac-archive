import '../config/app_config.dart';

/// One archive entry: a (year, subject) pair with up to three PDF URLs.
/// Mirrors the `exams` table in Supabase.
class Exam {
  const Exam({
    required this.id,
    required this.year,
    required this.stream,
    required this.subject,
    this.streams = const [],
    this.sujetUrl,
    this.solutionUrl,
    this.correctionUrl,
    this.fileSizeBytes = 0,
  });

  final String id;
  final String year;
  final String stream;
  final String subject;

  /// Streams that share this entry (falls back to [stream] when absent).
  final List<String> streams;
  final String? sujetUrl;
  final String? solutionUrl;
  final String? correctionUrl;
  final int fileSizeBytes;

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'] as String,
      year: map['year'].toString(),
      stream: (map['stream'] ?? '') as String,
      subject: (map['subject'] ?? '') as String,
      streams: (map['streams'] as List?)?.cast<String>() ??
          [if (map['stream'] != null) map['stream'] as String],
      sujetUrl: map['sujet_url'] as String?,
      solutionUrl: map['solution_url'] as String?,
      correctionUrl: map['correction_url'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'year': year,
        'stream': stream,
        'subject': subject,
        'streams': streams,
        'sujet_url': sujetUrl,
        'solution_url': solutionUrl,
        'correction_url': correctionUrl,
        'file_size_bytes': fileSizeBytes,
      };

  /// Remote URL for a given file kind (null if that file doesn't exist).
  String? urlFor(ExamFileKind kind) => switch (kind) {
        ExamFileKind.sujet => sujetUrl,
        ExamFileKind.solution => solutionUrl,
        ExamFileKind.correction => correctionUrl,
      };

  /// Every (kind, url) pair that actually has a file.
  Iterable<({ExamFileKind kind, String url})> get availableFiles sync* {
    for (final kind in ExamFileKind.values) {
      final url = urlFor(kind);
      if (url != null && url.isNotEmpty) yield (kind: kind, url: url);
    }
  }

  bool get hasAnyFile => availableFiles.isNotEmpty;
}
