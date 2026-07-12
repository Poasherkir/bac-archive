/// Human-readable byte size, e.g. 3.4 MB. Uses Western digits (fine for Arabic UI).
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  final str = i == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$str ${units[i]}';
}
