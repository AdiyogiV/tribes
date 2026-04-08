/// Stub for path package on web
/// Provides basic path manipulation for compatibility
library;

/// Join path segments
String join(String part1, [String? part2, String? part3, String? part4]) {
  final parts = [part1];
  if (part2 != null) parts.add(part2);
  if (part3 != null) parts.add(part3);
  if (part4 != null) parts.add(part4);
  return parts.join('/');
}

/// Get the directory name from a path
String dirname(String path) {
  final lastSlash = path.lastIndexOf('/');
  if (lastSlash < 0) return '.';
  return path.substring(0, lastSlash);
}

/// Get the base name from a path
String basename(String path) {
  final lastSlash = path.lastIndexOf('/');
  if (lastSlash < 0) return path;
  return path.substring(lastSlash + 1);
}

/// Get the extension from a path
String extension(String path) {
  final name = basename(path);
  final lastDot = name.lastIndexOf('.');
  if (lastDot < 0) return '';
  return name.substring(lastDot);
}

/// Get the path without extension
String withoutExtension(String path) {
  final ext = extension(path);
  if (ext.isEmpty) return path;
  return path.substring(0, path.length - ext.length);
}

/// Normalize a path
String normalize(String path) {
  return path.replaceAll('//', '/');
}

/// Check if path is absolute
bool isAbsolute(String path) {
  return path.startsWith('/');
}
