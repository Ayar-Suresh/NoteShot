import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/telemetry_service.dart';
import '../services/storage_service.dart';

class OverlayLaunchScreen extends StatefulWidget {
  final TelemetryService telemetryService;
  final StorageService storageService;

  const OverlayLaunchScreen({
    super.key,
    required this.telemetryService,
    required this.storageService,
  });

  @override
  State<OverlayLaunchScreen> createState() => _OverlayLaunchScreenState();
}

class _OverlayLaunchScreenState extends State<OverlayLaunchScreen> {
  bool _overlayActive = false;
  bool _permissionGranted = false;
  Timer? _pumpTimer;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _checkOverlayStatus();
  }

  Future<void> _checkPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  Future<void> _checkOverlayStatus() async {
    final active = await FlutterOverlayWindow.isActive();
    if (mounted) setState(() => _overlayActive = active);
  }

  Future<void> _requestPermission() async {
    await FlutterOverlayWindow.requestPermission();
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermission();
  }

  Future<void> _startOverlay() async {
    if (!_permissionGranted) {
      await _requestPermission();
      if (!_permissionGranted) return;
    }

    // Ensure GPS is streaming
    if (widget.telemetryService.status != TelemetryStatus.streaming) {
      await widget.telemetryService.startTracking();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      height: 280,
      width: 350,
      alignment: OverlayAlignment.topLeft,
      positionGravity: PositionGravity.auto,
    );

    _startDataPump();
    if (mounted) setState(() => _overlayActive = true);
  }

  void _startDataPump() {
    _pumpTimer?.cancel();
    _pumpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pushData();
    });
    // Push immediately
    _pushData();
  }

  void _pushData() {
    final t = widget.telemetryService.telemetry;
    final settings = widget.storageService.toOverlayPayload();
    final displayMap = t.toDisplayMap(use24Hour: widget.storageService.use24Hour);

    final payload = <String, dynamic>{
      ...settings,
      'lat': displayMap['Lat'],
      'lon': displayMap['Lon'],
      'elev': displayMap['Elev'],
      'hAcc': displayMap['H.Acc'],
      'vAcc': displayMap['V.Acc'],
      'time': displayMap['Time'],
    };

    FlutterOverlayWindow.shareData(jsonEncode(payload));
  }

  Future<void> _stopOverlay() async {
    _pumpTimer?.cancel();
    _pumpTimer = null;
    await FlutterOverlayWindow.closeOverlay();
    if (mounted) setState(() => _overlayActive = false);
  }

  @override
  void dispose() {
    _pumpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM OVERLAY'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission Status Card
            _buildPermissionCard(),
            const SizedBox(height: 16),

            // Overlay Control Card
            _buildOverlayControlCard(),
            const SizedBox(height: 16),

            // Info Card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _permissionGranted
              ? const Color(0xFF00E5CC).withOpacity(0.3)
              : const Color(0xFFFF6B6B).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_permissionGranted
                      ? const Color(0xFF00E5CC)
                      : const Color(0xFFFF6B6B))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _permissionGranted ? Icons.verified : Icons.shield,
              color: _permissionGranted
                  ? const Color(0xFF00E5CC)
                  : const Color(0xFFFF6B6B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Draw Over Apps',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _permissionGranted ? 'Permission granted' : 'Permission required',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!_permissionGranted)
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('GRANT', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayControlCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _overlayActive
              ? [const Color(0xFF00E5CC).withOpacity(0.15), const Color(0xFF1A2735)]
              : [const Color(0xFF1A2735), const Color(0xFF1A2735)],
        ),
        border: Border.all(
          color: _overlayActive
              ? const Color(0xFF00E5CC).withOpacity(0.4)
              : const Color(0xFF2A3A4A),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _overlayActive ? Icons.layers : Icons.layers_outlined,
            color: _overlayActive ? const Color(0xFF00E5CC) : const Color(0xFF556677),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _overlayActive ? 'Overlay Active' : 'Overlay Inactive',
            style: TextStyle(
              color: _overlayActive ? const Color(0xFF00E5CC) : Colors.white.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _overlayActive
                ? 'Telemetry badge is visible on screen. Use the home button to go to speed test apps.'
                : 'Start the overlay to display GPS telemetry over other apps.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _overlayActive ? _stopOverlay : _startOverlay,
              icon: Icon(_overlayActive ? Icons.stop_circle : Icons.play_arrow),
              label: Text(
                _overlayActive ? 'STOP OVERLAY' : 'START OVERLAY',
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _overlayActive
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF00E5CC),
                foregroundColor: _overlayActive ? Colors.white : const Color(0xFF0F1923),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: Colors.white.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoStep('1', 'Start GPS tracking from the dashboard'),
          _buildInfoStep('2', 'Launch the overlay to display telemetry'),
          _buildInfoStep('3', 'Switch to speed test apps (Fast.com, Ookla, etc.)'),
          _buildInfoStep('4', 'Take a native screenshot — GPS data will be visible'),
          _buildInfoStep('5', 'Return here to stop the overlay when done'),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5CC).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              num,
              style: const TextStyle(
                color: Color(0xFF00E5CC),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
