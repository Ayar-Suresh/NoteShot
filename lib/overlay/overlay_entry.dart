import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayEntryWidget extends StatefulWidget {
  const OverlayEntryWidget({super.key});

  @override
  State<OverlayEntryWidget> createState() => _OverlayEntryWidgetState();
}

class _OverlayEntryWidgetState extends State<OverlayEntryWidget> {
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((rawData) {
      if (rawData is String && rawData.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawData) as Map<String, dynamic>;
          if (mounted) {
            setState(() => _data = decoded);
          }
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = (_data['fontSize'] as num?)?.toDouble() ?? 13.0;
    final double bgOpacity = (_data['bgOpacity'] as num?)?.toDouble() ?? 0.75;
    final bool showLat = _data['showLat'] as bool? ?? true;
    final bool showLon = _data['showLon'] as bool? ?? true;
    final bool showElev = _data['showElev'] as bool? ?? true;
    final bool showAccuracy = _data['showAccuracy'] as bool? ?? true;
    final bool showNotes = _data['showNotes'] as bool? ?? true;
    final bool showTime = _data['showTime'] as bool? ?? true;
    final String noteText = _data['noteText'] as String? ?? '';
    final int colorIndex = (_data['textColorIndex'] as num?)?.toInt() ?? 0;

    // Telemetry fields
    final String lat = _data['lat'] as String? ?? '--';
    final String lon = _data['lon'] as String? ?? '--';
    final String elev = _data['elev'] as String? ?? '--';
    final String hAcc = _data['hAcc'] as String? ?? '--';
    final String vAcc = _data['vAcc'] as String? ?? '--';
    final String time = _data['time'] as String? ?? '--';

    final List<Color> textColors = [
      const Color(0xFF00E5CC), // Cyan/teal
      const Color(0xFFFFFFFF), // White
      const Color(0xFFFFD700), // Gold
      const Color(0xFF00FF88), // Green
      const Color(0xFFFF6B6B), // Red
    ];
    final Color textColor = textColors[colorIndex.clamp(0, textColors.length - 1)];

    final List<String> lines = [];
    if (showLat) lines.add('LAT  $lat');
    if (showLon) lines.add('LON  $lon');
    if (showElev) lines.add('ELEV $elev');
    if (showAccuracy) {
      lines.add('H.ACC $hAcc');
      lines.add('V.ACC $vAcc');
    }
    if (showTime) lines.add('TIME $time');
    if (showNotes && noteText.isNotEmpty) lines.add('NOTE $noteText');

    if (lines.isEmpty) {
      lines.add('NoteShot Active');
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () async {
          await FlutterOverlayWindow.getOverlayPosition();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(bgOpacity),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: textColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSize,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
