import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/telemetry_model.dart';

enum TelemetryStatus {
  idle,
  requesting,
  streaming,
  denied,
  serviceOff,
  error,
}

class TelemetryService extends ChangeNotifier {
  Telemetry _telemetry = Telemetry.empty();
  TelemetryStatus _status = TelemetryStatus.idle;
  StreamSubscription<Position>? _positionSub;
  String? _errorMessage;

  Telemetry get telemetry => _telemetry;
  TelemetryStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> startTracking() async {
    if (_status == TelemetryStatus.streaming) return;

    _status = TelemetryStatus.requesting;
    _errorMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = TelemetryStatus.serviceOff;
        _errorMessage = 'Location services are disabled.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _status = TelemetryStatus.denied;
          _errorMessage = 'Location permission denied.';
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _status = TelemetryStatus.denied;
        _errorMessage =
            'Location permission permanently denied. Please enable in Settings.';
        notifyListeners();
        return;
      }

      _status = TelemetryStatus.streaming;
      notifyListeners();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _telemetry = Telemetry(
            latitude: position.latitude,
            longitude: position.longitude,
            elevation: position.altitude,
            horizontalAccuracy: position.accuracy,
            verticalAccuracy: position.altitudeAccuracy,
            timestamp: position.timestamp,
          );
          notifyListeners();
        },
        onError: (error) {
          _status = TelemetryStatus.error;
          _errorMessage = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _status = TelemetryStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _status = TelemetryStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}
