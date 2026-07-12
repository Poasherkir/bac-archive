import 'dart:io';

/// Thrown when a download is aborted via the cancellation callback.
class SyncCancelled implements Exception {
  const SyncCancelled();
}

/// Streams a file to disk with byte-level progress. Cancel-safe and resumable:
/// writes to a `.part` temp file and only renames to the final path on success,
/// so an interrupted download never leaves a half-written "complete" file.
class Downloader {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  Future<void> download(
    String url,
    String destPath, {
    void Function(int chunkBytes)? onBytes,
    bool Function()? isCancelled,
  }) async {
    final dest = File(destPath);
    await dest.parent.create(recursive: true);

    // Already downloaded? nothing to do (resume support).
    if (await dest.exists()) return;

    final part = File('$destPath.part');
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }

    final sink = part.openWrite();
    try {
      await for (final chunk in response) {
        if (isCancelled?.call() ?? false) {
          throw const SyncCancelled();
        }
        sink.add(chunk);
        onBytes?.call(chunk.length);
      }
      await sink.flush();
      await sink.close();
      await part.rename(destPath);
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await part.exists()) {
        await part.delete().catchError((_) => part);
      }
      rethrow;
    }
  }
}
