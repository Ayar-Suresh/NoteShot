import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/telemetry_model.dart';
import 'storage_service.dart';

enum TelemetryStatus {
  idle,
  requesting,
  streaming,
  denied,
  serviceOff,
  error,
}

class TelemetryService extends ChangeNotifier {
  final StorageService storageService;

  TelemetryService(this.storageService);

  Telemetry _telemetry = Telemetry.empty();
  TelemetryStatus _status = TelemetryStatus.idle;
  StreamSubscription<Position>? _positionSub;
  String? _errorMessage;
  final List<double> _elevationHistory = [];
  Timer? _mockTimer;

  Telemetry get telemetry => _telemetry;
  TelemetryStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> startTracking() async {
    if (_status == TelemetryStatus.streaming) return;

    // Defer execution to prevent synchronous notifyListeners during widget build/initState
    await Future.microtask(() {});

    if (storageService.useMockLocation) {
      _status = TelemetryStatus.streaming;
      _errorMessage = null;
      _mockTimer?.cancel();
      final random = math.Random();
      _mockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        DateTime ts = DateTime.now();
        final cTime = storageService.customTime;
        if (cTime != null && cTime.isNotEmpty) {
          ts = DateTime.tryParse(cTime) ?? ts;
        }

        // Realistic accuracy between 2.0 and 5.0
        final mockAccuracy = 2.0 + (random.nextDouble() * 3.0);
        // Realistic base elevation from real map data + small +/- 0.5m noise
        final mockElevation = storageService.customElev + (random.nextDouble() - 0.5);

        _telemetry = Telemetry(
          latitude: storageService.customLat,
          longitude: storageService.customLon,
          elevation: mockElevation,
          horizontalAccuracy: mockAccuracy,
          verticalAccuracy: mockAccuracy,
          timestamp: ts,
        );
        notifyListeners();
      });
      notifyListeners();
      return;
    }

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
          _elevationHistory.add(position.altitude);
          if (_elevationHistory.length > 5) {
            _elevationHistory.removeAt(0);
          }
          final smoothedElevation = _elevationHistory.reduce((a, b) => a + b) / _elevationHistory.length;

          DateTime ts = position.timestamp;
          final cTime = storageService.customTime;
          if (cTime != null && cTime.isNotEmpty) {
            ts = DateTime.tryParse(cTime) ?? ts;
          }

          _telemetry = Telemetry(
            latitude: position.latitude,
            longitude: position.longitude,
            elevation: smoothedElevation,
            horizontalAccuracy: position.accuracy,
            verticalAccuracy: position.altitudeAccuracy,
            timestamp: ts,
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

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> stopTracking() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _status = TelemetryStatus.idle;
    _elevationHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
