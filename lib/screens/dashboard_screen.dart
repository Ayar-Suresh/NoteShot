import 'dart:async';
import 'package:flutter/material.dart';
import '../services/telemetry_service.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  final TelemetryService telemetryService;
  final StorageService storageService;

  const DashboardScreen({
    super.key,
    required this.telemetryService,
    required this.storageService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TextEditingController _noteController;
  Timer? _debounceTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.storageService.noteText);
    widget.telemetryService.addListener(_onTelemetryUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _onTelemetryUpdate() {
    if (mounted) setState(() {});
  }

  void _onNoteChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      widget.storageService.setNoteText(value);
    });
  }

  Future<void> _toggleTracking() async {
    if (widget.telemetryService.status == TelemetryStatus.streaming) {
      await widget.telemetryService.stopTracking();
    } else {
      await widget.telemetryService.startTracking();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.telemetryService.removeListener(_onTelemetryUpdate);
    _noteController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.telemetryService.status;
    final telemetry = widget.telemetryService.telemetry;
    final isStreaming = status == TelemetryStatus.streaming;
    final use24 = widget.storageService.use24Hour;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5CC), Color(0xFF00B4D8)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.gps_fixed, color: Color(0xFF0F1923), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('NOTESHOT'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(context, '/settings').then((_) => setState(() {})),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator bar
            _buildStatusBar(status),
            const SizedBox(height: 16),

            // Live Telemetry Card
            _buildTelemetryCard(status, telemetry, use24),
            const SizedBox(height: 16),

            // Note Input
            _buildNoteField(),
            const SizedBox(height: 20),

            // Navigation Grid Title
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'WORKFLOWS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ),

            // Navigation Grid
            _buildNavigationGrid(context),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(isStreaming),
    );
  }

  Widget _buildStatusBar(TelemetryStatus status) {
    final Map<TelemetryStatus, (IconData, String, Color)> statusMap = {
      TelemetryStatus.idle: (Icons.gps_off, 'GPS Idle', const Color(0xFF556677)),
      TelemetryStatus.requesting: (Icons.sync, 'Acquiring Signal...', const Color(0xFFFFAA00)),
      TelemetryStatus.streaming: (Icons.gps_fixed, 'Live Tracking', const Color(0xFF00E5CC)),
      TelemetryStatus.denied: (Icons.block, 'Permission Denied', const Color(0xFFFF6B6B)),
      TelemetryStatus.serviceOff: (Icons.location_off, 'Location Off', const Color(0xFFFF6B6B)),
      TelemetryStatus.error: (Icons.error_outline, 'Error', const Color(0xFFFF6B6B)),
    };

    final info = statusMap[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: info.$3.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.$3.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (status == TelemetryStatus.streaming)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: info.$3.withValues(alpha: _pulseAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: info.$3.withValues(alpha: _pulseAnimation.value * 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Icon(info.$1, color: info.$3, size: 16),
          const SizedBox(width: 10),
          Text(
            info.$2,
            style: TextStyle(
              color: info.$3,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (status == TelemetryStatus.denied || status == TelemetryStatus.serviceOff)
            GestureDetector(
              onTap: () => widget.telemetryService.startTracking(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: info.$3.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RETRY',
                  style: TextStyle(
                    color: info.$3,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(
      TelemetryStatus status, dynamic telemetry, bool use24) {
    final displayMap = telemetry.toDisplayMap(use24Hour: use24);
    final isLoading = status == TelemetryStatus.requesting;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2735),
            const Color(0xFF1A2735).withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF00E5CC).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5CC).withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.satellite_alt,
                    color: Color(0xFF00E5CC), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'TELEMETRY',
                  style: TextStyle(
                    color: Color(0xFF00E5CC),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFFFFAA00)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...displayMap.entries.map((e) => _buildTelemetryRow(
                  e.key,
                  status == TelemetryStatus.idle ? '--' : e.value,
                  isLoading,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment(
                                -1.0 + 2.0 * _shimmerController.value, 0),
                            end: Alignment(
                                1.0 + 2.0 * _shimmerController.value, 0),
                            colors: const [
                              Color(0xFF2A3A4A),
                              Color(0xFF3A4A5A),
                              Color(0xFF2A3A4A),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFE0E6ED),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'LOCATION NOTE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ),
        TextField(
          controller: _noteController,
          onChanged: _onNoteChanged,
          style: const TextStyle(color: Color(0xFFE0E6ED), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g., Sanghavi Infotech, Japan, China',
            prefixIcon: const Icon(Icons.edit_location_alt,
                color: Color(0xFF00E5CC), size: 20),
            suffixIcon: _noteController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.white.withValues(alpha: 0.3), size: 18),
                    onPressed: () {
                      _noteController.clear();
                      _onNoteChanged('');
                      setState(() {});
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    final items = [
      _NavItem('System\nOverlay', Icons.layers, [const Color(0xFF00E5CC), const Color(0xFF00B4D8)], '/overlay'),
      _NavItem('Camera\nCapture', Icons.camera_alt, [const Color(0xFF6C63FF), const Color(0xFF3B82F6)], '/camera'),
      _NavItem('Stamp\nScreenshot', Icons.photo_filter, [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)], '/stamper'),
      _NavItem('Speed\nTest', Icons.speed, [const Color(0xFF00C9A7), const Color(0xFF845EC2)], '/browser'),
      _NavItem('Zabbix\nMonitor', Icons.monitor_heart, [const Color(0xFF00B4D8), const Color(0xFF6C63FF)], '/zabbix'),
      _NavItem('Cyber\nPing', Icons.terminal, [const Color(0xFF00FF41), const Color(0xFF00E5CC)], '/ping'),
      _NavItem('Settings', Icons.tune, [const Color(0xFF556677), const Color(0xFF3A4A5A)], '/settings'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNavCard(context, item);
      },
    );
  }

  Widget _buildNavCard(BuildContext context, _NavItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route)
            .then((_) => setState(() {})),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.gradient[0].withValues(alpha: 0.15),
                item.gradient[1].withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: item.gradient[0].withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: item.gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: Colors.white, size: 18),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFFE0E6ED),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(bool isStreaming) {
    return FloatingActionButton.extended(
      onPressed: _toggleTracking,
      backgroundColor: isStreaming ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC),
      foregroundColor: isStreaming ? Colors.white : const Color(0xFF0F1923),
      icon: Icon(isStreaming ? Icons.stop_circle : Icons.play_arrow),
      label: Text(
        isStreaming ? 'STOP GPS' : 'START GPS',
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  _NavItem(this.label, this.icon, this.gradient, this.route);
}
