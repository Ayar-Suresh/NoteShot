import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

class HiddenSettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final TelemetryService telemetryService;

  const HiddenSettingsScreen({
    super.key,
    required this.storageService,
    required this.telemetryService,
  });

  @override
  State<HiddenSettingsScreen> createState() => _HiddenSettingsScreenState();
}

class _HiddenSettingsScreenState extends State<HiddenSettingsScreen> {
  late bool _useIST;
  late bool _useMockLocation;
  late double _customLat;
  late double _customLon;
  String? _customTime;

  @override
  void initState() {
    super.initState();
    _useIST = widget.storageService.useIST;
    _useMockLocation = widget.storageService.useMockLocation;
    _customLat = widget.storageService.customLat;
    _customLon = widget.storageService.customLon;
    _customTime = widget.storageService.customTime;
  }

  Future<void> _pickLocation() async {
    await Navigator.pushNamed(context, '/map_picker');
    setState(() {
      _customLat = widget.storageService.customLat;
      _customLon = widget.storageService.customLon;
    });
    if (_useMockLocation) widget.telemetryService.startTracking(); 
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          _customTime = dt.toIso8601String();
        });
        widget.storageService.setCustomTime(_customTime);
        if (_useMockLocation) widget.telemetryService.startTracking(); 
      }
    }
  }

  void _clearTime() {
    setState(() {
      _customTime = null;
    });
    widget.storageService.setCustomTime(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADJUSTMENTS (HIDDEN)'),
        backgroundColor: const Color(0xFF0D1520),
      ),
      backgroundColor: const Color(0xFF080D14),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2535),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Use Indian Standard Time (IST)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Force timestamp to IST (UTC+5:30)', style: TextStyle(color: Colors.white54)),
                  value: _useIST,
                  activeColor: const Color(0xFF00FFD1),
                  onChanged: (val) {
                    setState(() => _useIST = val);
                    widget.storageService.setUseIST(val);
                  },
                ),
                const Divider(color: Colors.white10),
                SwitchListTile(
                  title: const Text('Enable Mock Location & Time', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Bypass GPS permissions and use custom values', style: TextStyle(color: Colors.white54)),
                  value: _useMockLocation,
                  activeColor: const Color(0xFF00FFD1),
                  onChanged: (val) {
                    setState(() => _useMockLocation = val);
                    widget.storageService.setUseMockLocation(val);
                    if (val) {
                      widget.telemetryService.startTracking();
                    } else {
                      widget.telemetryService.stopTracking(); // stop mock timer
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_useMockLocation) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2535),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOCK LOCATION: ${_customLat.toStringAsFixed(5)}, ${_customLon.toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF00FFD1), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map),
                    label: const Text('PICK MOCK LOCATION ON MAP'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('CUSTOM TIME: ${_customTime != null ? DateTime.parse(_customTime!).toLocal().toString().split('.')[0] : 'None (Using Real Time)'}', style: const TextStyle(color: Color(0xFF00FFD1), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: const Text('SET TIME'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFD1),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _clearTime,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('CLEAR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
