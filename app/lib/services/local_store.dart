import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/exam.dart';

/// Owns everything on-device: the mirrored PDF files, the cached manifest,
/// and the sync-complete flag. All local paths mirror the storage layout
/// ({year}/sciences/{slug}/{file}.pdf) derived straight from the public URL,
/// so the local tree always matches Supabase Storage exactly.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;
  Directory? _base;

  static const kSyncCompleteKey = 'sync_complete'; // legacy (= sciences)

  /// Completion flags. Any earlier flag (legacy single-stream or per-stream
  /// sciences) counts as "content present" so updated installs boot straight
  /// to Home while the delta sync tops up the remaining streams.
  bool isSyncCompleteFor(String slug) =>
      (_prefs.getBool('sync_complete_$slug') ?? false) ||
      (slug == 'all' &&
          ((_prefs.getBool(kSyncCompleteKey) ?? false) ||
              (_prefs.getBool('sync_complete_sci') ?? false))) ||
      (slug == 'sci' && (_prefs.getBool(kSyncCompleteKey) ?? false));

  Future<void> setSyncCompleteFor(String slug) =>
      _prefs.setBool('sync_complete_$slug', true);

  Future<Directory> baseDir() async {
    if (_base != null) return _base!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/bac_files');
    if (!await dir.exists()) await dir.create(recursive: true);
    _base = dir;
    return dir;
  }

  /// Storage-relative path from a public URL, e.g.
  ///   .../object/public/bac-files/2024/sciences/maths/sujet.pdf
  ///   -> 2024/sciences/maths/sujet.pdf
  String relativePathForUrl(String url) {
    final marker = '/public/${AppConfig.storageBucket}/';
    final i = url.indexOf(marker);
    var rel = i >= 0
        ? url.substring(i + marker.length)
        : Uri.parse(url).pathSegments.join('/');
    rel = rel.split('?').first; // drop any query string
    return Uri.decodeComponent(rel);
  }

  Future<String> localPathForUrl(String url) async {
    final base = await baseDir();
    return '${base.path}/${relativePathForUrl(url)}';
  }

  Future<bool> existsForUrl(String url) async =>
      File(await localPathForUrl(url)).exists();

  // --- manifest cache (drives the fully-offline Home) -----------------------
  Future<File> _manifestFile(String slug) async =>
      File('${(await baseDir()).path}/manifest_$slug.json');

  Future<void> saveManifest(String slug, List<Exam> exams) async {
    final file = await _manifestFile(slug);
    await file.writeAsString(
      jsonEncode(exams.map((e) => e.toMap()).toList()),
    );
  }

  Future<List<Exam>> readManifest(String slug) async {
    var file = await _manifestFile(slug);
    if (!await file.exists() && (slug == 'sci' || slug == 'all')) {
      // Fallbacks for pre-all-streams installs: per-stream sciences
      // manifest, then the original single-stream file.
      final sci = await _manifestFile('sci');
      file = await sci.exists()
          ? sci
          : File('${(await baseDir()).path}/manifest.json');
    }
    if (!await file.exists()) return [];
    final decoded = jsonDecode(await file.readAsString()) as List;
    return decoded
        .map((e) => Exam.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
