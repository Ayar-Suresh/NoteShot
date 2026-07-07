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
  Timer? _tickerTimer;
  Position? _lastPosition;

  Telemetry get telemetry => _telemetry;
  TelemetryStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> forceRefresh() async {
    await stopTracking();
    await startTracking();
  }

  Future<void> startTracking() async {
    if (_status == TelemetryStatus.streaming) return;

    // Defer execution to prevent synchronous notifyListeners during widget build/initState
    await Future.microtask(() {});

    _tickerTimer?.cancel();
    _errorMessage = null;

    if (storageService.useMockLocation) {
      _status = TelemetryStatus.streaming;
      final random = math.Random();
      
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        DateTime ts = DateTime.now();
        final cTime = storageService.customTime;
        if (cTime != null && cTime.isNotEmpty) {
          ts = DateTime.tryParse(cTime) ?? ts;
        }

        final mockAccuracy = 2.0 + (random.nextDouble() * 3.0);
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
      
      // Start continuous ticker for real GPS so the clock always ticks!
      _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_lastPosition != null) {
          DateTime ts = DateTime.now();
          final cTime = storageService.customTime;
          // Only apply custom time if mock location is enabled (per user request) or if we want to allow it globally. 
          // The user said: "you can ingnore those realtime chances when we are using enable mock location and time feature but for gps when that feature is disable(and even in defual situation) always use realtime values"
          // So for real GPS, ALWAYS use DateTime.now()
          
          _telemetry = Telemetry(
            latitude: _lastPosition!.latitude,
            longitude: _lastPosition!.longitude,
            elevation: _telemetry.elevation > 0 ? _telemetry.elevation : _lastPosition!.altitude,
            horizontalAccuracy: _lastPosition!.accuracy,
            verticalAccuracy: _lastPosition!.altitudeAccuracy,
            timestamp: ts,
          );
          notifyListeners();
        }
      });
      
      notifyListeners();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      _positionSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          
          _elevationHistory.add(position.altitude);
          if (_elevationHistory.length > 5) {
            _elevationHistory.removeAt(0);
          }
          final smoothedElevation = _elevationHistory.reduce((a, b) => a + b) / _elevationHistory.length;
          
          _telemetry = Telemetry(
            latitude: position.latitude,
            longitude: position.longitude,
            elevation: smoothedElevation,
            horizontalAccuracy: position.accuracy,
            verticalAccuracy: position.altitudeAccuracy,
            timestamp: DateTime.now(), // Always realtime
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
    _tickerTimer?.cancel();
    _tickerTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _status = TelemetryStatus.idle;
    _elevationHistory.clear();
    _lastPosition = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
