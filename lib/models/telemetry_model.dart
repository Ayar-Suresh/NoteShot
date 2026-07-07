class Telemetry {
  final double latitude;
  final double longitude;
  final double elevation;
  final double horizontalAccuracy;
  final double verticalAccuracy;
  final DateTime timestamp;

  const Telemetry({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.horizontalAccuracy,
    required this.verticalAccuracy,
    required this.timestamp,
  });

  factory Telemetry.empty() => Telemetry(
        latitude: 0.0,
        longitude: 0.0,
        elevation: 0.0,
        horizontalAccuracy: 0.0,
        verticalAccuracy: 0.0,
        timestamp: DateTime.now(),
      );

  Map<String, String> toDisplayMap({bool use24Hour = false, bool useIST = false}) {
    DateTime displayTime = timestamp;
    if (useIST) {
      displayTime = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    }
    
    final dateStr = '${displayTime.day.toString().padLeft(2, '0')}-${displayTime.month.toString().padLeft(2, '0')}-${displayTime.year}';
    final ts = use24Hour
        ? '${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}'
        : _to12Hour(displayTime);
    final fullTs = '$dateStr $ts';
    return {
      'Lat': latitude.toStringAsFixed(6),
      'Lon': longitude.toStringAsFixed(6),
      'Elev': '${elevation.toStringAsFixed(2)}±${verticalAccuracy.toStringAsFixed(1)} m',
      'Acc': '${horizontalAccuracy.toStringAsFixed(3)} m',
      'Time': fullTs,
    };
  }

  String _to12Hour(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'elevation': elevation,
        'horizontalAccuracy': horizontalAccuracy,
        'verticalAccuracy': verticalAccuracy,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Telemetry.fromJson(Map<String, dynamic> json) => Telemetry(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        horizontalAccuracy:
            (json['horizontalAccuracy'] as num?)?.toDouble() ?? 0.0,
        verticalAccuracy:
            (json['verticalAccuracy'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}
