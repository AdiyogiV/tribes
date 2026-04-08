import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:aurogram/core/logging/app_logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  String? _cachedLocationString;
  DateTime? _cacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  /// Get user's current location as a readable string
  /// Returns cached location if available and fresh
  /// Format: "City, Country" or "Latitude, Longitude" if geocoding fails
  Future<String?> getCurrentLocationString() async {
    try {
      // Return cached location if still valid
      if (_cachedLocationString != null && _cacheTime != null) {
        final age = DateTime.now().difference(_cacheTime!);
        if (age < _cacheValidDuration) {
          return _cachedLocationString;
        }
      }

      // Check permissions
      final permission = await _checkPermissions();
      if (!permission) {
        AppLogger.w('Location permissions denied');
        return null;
      }

      // Get position
      final position = await _getCurrentPosition();
      if (position == null) return null;

      // Try to get readable address
      String locationString;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final city =
              placemark.locality ?? placemark.subAdministrativeArea ?? '';
          final country = placemark.country ?? '';

          if (city.isNotEmpty && country.isNotEmpty) {
            locationString = '$city, $country';
          } else if (city.isNotEmpty) {
            locationString = city;
          } else if (country.isNotEmpty) {
            locationString = country;
          } else {
            locationString =
                '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
          }
        } else {
          locationString =
              '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
        }
      } catch (e) {
        AppLogger.w('Geocoding failed: $e');
        locationString =
            '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      }

      // Cache the result
      _cachedLocationString = locationString;
      _cacheTime = DateTime.now();

      AppLogger.i('Location obtained: $locationString');
      return locationString;
    } catch (e) {
      AppLogger.e('Location service error: $e');
      return null;
    }
  }

  /// Check and request location permissions with timeout
  Future<bool> _checkPermissions() async {
    try {
      // Add timeout to prevent hanging during startup
      final checkFuture = Future(() async {
        bool serviceEnabled;
        LocationPermission permission;

        // Check if location services are enabled
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          AppLogger.w('Location services are disabled');
          return false;
        }

        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            AppLogger.w('Location permissions are denied');
            return false;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          AppLogger.w('Location permissions are permanently denied');
          return false;
        }

        return true;
      });

      return await checkFuture.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          AppLogger.w('Location permission check timed out');
          return false;
        },
      );
    } catch (e) {
      AppLogger.e('Permission check error: $e');
      return false; // Gracefully fail if plugin isn't working
    }
  }

  /// Get current GPS position
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      AppLogger.e('Failed to get position: $e');
      return null;
    }
  }

  /// Clear cached location (force refresh on next request)
  void clearCache() {
    _cachedLocationString = null;
    _cacheTime = null;
  }

  /// Request location permission without getting location
  Future<bool> requestPermission() async {
    return await _checkPermissions();
  }
}
