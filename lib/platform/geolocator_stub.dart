/// Stub implementation of geolocator for web
/// Web uses browser Geolocation API differently
library;

enum LocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
}

class Position {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double speedAccuracy;
  final double heading;
  final DateTime timestamp;

  Position({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    this.altitude = 0,
    this.speed = 0,
    this.speedAccuracy = 0,
    this.heading = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class Geolocator {
  static Future<bool> isLocationServiceEnabled() async {
    return false;
  }

  static Future<LocationPermission> checkPermission() async {
    return LocationPermission.denied;
  }

  static Future<LocationPermission> requestPermission() async {
    return LocationPermission.denied;
  }

  static Future<Position> getCurrentPosition({
    dynamic desiredAccuracy,
    bool forceAndroidLocationManager = false,
    Duration? timeLimit,
  }) async {
    return Position(latitude: 0, longitude: 0);
  }
}
