import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Real-time location service for NaariRakshak using high-accuracy GPS / HTML5 Geolocation.
class LocationService {
  // Default fallback center (Kalkaji, New Delhi) if location services are disabled
  static const defaultLocation = LatLng(28.5494, 77.2501);

  final _positionController = StreamController<LatLng>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _lastKnownLocation;

  /// Broadcast stream of live GPS location updates.
  Stream<LatLng> get locationStream => _positionController.stream;

  /// Most recent detected GPS position.
  LatLng get currentLocation => _lastKnownLocation ?? defaultLocation;

  /// Determines the user's exact current location.
  ///
  /// Requests GPS permissions if needed, enables high accuracy, and handles fallback.
  Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return defaultLocation;
      }

      // Fetch high accuracy exact GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final loc = LatLng(position.latitude, position.longitude);
      _lastKnownLocation = loc;
      return loc;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return defaultLocation;
    }
  }

  /// Starts continuous real-time high-accuracy GPS tracking stream.
  void startTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update every 3 meters moved
      ),
    ).listen(
      (position) {
        final loc = LatLng(position.latitude, position.longitude);
        _lastKnownLocation = loc;
        _positionController.add(loc);
      },
      onError: (err) {
        debugPrint('Location stream error: $err');
      },
    );
  }

  /// Stop location stream subscription.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
