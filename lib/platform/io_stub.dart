/// Stub for dart:io on web
/// Provides minimal File/Directory classes for conditional compilation
/// All methods return safe defaults since file operations aren't available on web
library;

// Base class must be defined first
class FileSystemEntity {
  final String path;
  
  FileSystemEntity(this.path);
  
  static Future<bool> isFile(String path) async => false;
  
  static Future<bool> isDirectory(String path) async => false;
  
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;
  
  Future<bool> exists() async => false;
}

class File extends FileSystemEntity {
  File(super.path);
  
  bool existsSync() => false;
  
  @override
  Future<bool> exists() async => false;
  
  Future<List<int>> readAsBytes() async => [];
  
  Future<String> readAsString() async => '';
  
  Future<File> writeAsBytes(List<int> bytes) async => this;
  
  Future<File> writeAsString(String contents) async => this;
  
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;
  
  Future<File> copy(String newPath) async => File(newPath);
  
  File get absolute => this;
  
  int lengthSync() => 0;
  
  Future<int> length() async => 0;
  
  Uri get uri => Uri.file(path);
}

class Directory extends FileSystemEntity {
  Directory(super.path);
  
  bool existsSync() => false;
  
  @override
  Future<bool> exists() async => false;
  
  Future<Directory> create({bool recursive = false}) async => this;
  
  List<FileSystemEntity> listSync({bool recursive = false}) => [];
  
  Stream<FileSystemEntity> list({bool recursive = false}) => Stream.empty();
  
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async => this;
  
  Directory get absolute => this;
}

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static String get localHostname => 'localhost';
  static int get numberOfProcessors => 1;
  static String get pathSeparator => '/';
  static Map<String, String> get environment => {};
}

class FileSystemException implements Exception {
  final String message;
  final String? path;
  final dynamic osError;
  
  FileSystemException([this.message = '', this.path, this.osError]);
  
  @override
  String toString() => 'FileSystemException: $message';
}
