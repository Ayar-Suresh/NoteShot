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

class _OverlayLaunchScreenState extends State<OverlayLaunchScreen>
    with SingleTickerProviderStateMixin {
  bool _overlayActive = false;
  bool _permissionGranted = false;
  Timer? _pumpTimer;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _checkOverlayStatus();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
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
    final displayMap =
        t.toDisplayMap(use24Hour: widget.storageService.use24Hour);

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
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedEntry(int index, Widget child) {
    final delay = index * 0.15;
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final progress =
            ((_entranceController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - curved)),
            child: child,
          ),
        );
      },
    );
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
            _buildAnimatedEntry(0, _buildPermissionCard()),
            const SizedBox(height: 16),

            // Overlay Control Card
            _buildAnimatedEntry(1, _buildOverlayControlCard()),
            const SizedBox(height: 16),

            // Info Card
            _buildAnimatedEntry(2, _buildInfoCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    final statusColor = _permissionGranted
        ? const Color(0xFF00FFD1)
        : const Color(0xFFFF4757);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.1)),
            ),
            child: Icon(
              _permissionGranted ? Icons.verified : Icons.shield,
              color: statusColor,
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
                  _permissionGranted
                      ? 'Permission granted'
                      : 'Permission required',
                  style: TextStyle(
                    color: statusColor.withOpacity(0.6),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (!_permissionGranted)
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('GRANT', style: TextStyle(fontSize: 11)),
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
        color: const Color(0xFF0D1520),
        border: Border.all(
          color: _overlayActive
              ? const Color(0xFF00FFD1).withOpacity(0.2)
              : const Color(0xFF00FFD1).withOpacity(0.05),
        ),
        boxShadow: _overlayActive
            ? [
                BoxShadow(
                  color: const Color(0xFF00FFD1).withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _overlayActive
                  ? const Color(0xFF00FFD1).withOpacity(0.08)
                  : const Color(0xFF1A2535).withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _overlayActive ? Icons.layers : Icons.layers_outlined,
              color: _overlayActive
                  ? const Color(0xFF00FFD1)
                  : const Color(0xFF3A4A5A),
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _overlayActive ? 'Overlay Active' : 'Overlay Inactive',
            style: TextStyle(
              color: _overlayActive
                  ? const Color(0xFF00FFD1)
                  : Colors.white.withOpacity(0.5),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _overlayActive
                ? 'Telemetry badge is visible on screen. Use the home button to go to speed test apps.'
                : 'Start the overlay to display GPS telemetry over other apps.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _overlayActive ? _stopOverlay : _startOverlay,
              icon: Icon(
                  _overlayActive ? Icons.stop_circle : Icons.play_arrow),
              label: Text(
                _overlayActive ? 'STOP OVERLAY' : 'START OVERLAY',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _overlayActive
                    ? const Color(0xFFFF4757)
                    : const Color(0xFF00FFD1),
                foregroundColor: _overlayActive
                    ? Colors.white
                    : const Color(0xFF080D14),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
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
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFD1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.info_outline,
                    color: Colors.white.withOpacity(0.4), size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoStep('01', 'Start GPS tracking from the dashboard'),
          _buildInfoStep('02', 'Launch the overlay to display telemetry'),
          _buildInfoStep(
              '03', 'Switch to speed test apps (Fast.com, Ookla, etc.)'),
          _buildInfoStep(
              '04', 'Take a native screenshot — GPS data will be visible'),
          _buildInfoStep(
              '05', 'Return here to stop the overlay when done'),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF00FFD1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFF00FFD1).withOpacity(0.1)),
            ),
            child: Text(
              num,
              style: const TextStyle(
                color: Color(0xFF00FFD1),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
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
