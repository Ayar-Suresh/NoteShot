import 'dart:async';
import 'dart:math';
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
  late AnimationController _fabGlowController;
  late Animation<double> _fabGlowAnimation;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: widget.storageService.noteText);
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

    _fabGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _fabGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabGlowController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
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
    _fabGlowController.dispose();
    _entranceController.dispose();
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
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FFD1), Color(0xFF00B4D8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFD1)
                            .withOpacity(_pulseAnimation.value * 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub,
                      color: Color(0xFF080D14), size: 16),
                );
              },
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00FFD1), Color(0xFF00B4D8)],
              ).createShader(bounds),
              child: const Text(
                'NETFORGE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFD1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, size: 18),
            ),
            onPressed: () => Navigator.pushNamed(context, '/settings')
                .then((_) => setState(() {})),
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
            _buildAnimatedEntry(0, _buildStatusBar(status)),
            const SizedBox(height: 16),

            // Live Telemetry Card
            _buildAnimatedEntry(1, _buildTelemetryCard(status, telemetry, use24)),
            const SizedBox(height: 16),

            // Note Input
            _buildAnimatedEntry(2, _buildNoteField()),
            const SizedBox(height: 20),

            // Navigation Grid Title
            _buildAnimatedEntry(
              3,
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FFD1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WORKFLOWS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
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

  Widget _buildAnimatedEntry(int index, Widget child) {
    final delay = index * 0.12;
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final progress =
            ((_entranceController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curved)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(TelemetryStatus status) {
    final Map<TelemetryStatus, (IconData, String, Color)> statusMap = {
      TelemetryStatus.idle: (
        Icons.gps_off,
        'GPS Idle',
        const Color(0xFF3A4A5A)
      ),
      TelemetryStatus.requesting: (
        Icons.sync,
        'Acquiring Signal...',
        const Color(0xFFFFAA00)
      ),
      TelemetryStatus.streaming: (
        Icons.gps_fixed,
        'Live Tracking',
        const Color(0xFF00FFD1)
      ),
      TelemetryStatus.denied: (
        Icons.block,
        'Permission Denied',
        const Color(0xFFFF4757)
      ),
      TelemetryStatus.serviceOff: (
        Icons.location_off,
        'Location Off',
        const Color(0xFFFF4757)
      ),
      TelemetryStatus.error: (
        Icons.error_outline,
        'Error',
        const Color(0xFFFF4757)
      ),
    };

    final info = statusMap[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: info.$3.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.$3.withOpacity(0.15)),
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
                    color: info.$3.withOpacity(_pulseAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: info.$3
                            .withOpacity(_pulseAnimation.value * 0.5),
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
              fontSize: 12,
              letterSpacing: 0.8,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (status == TelemetryStatus.denied ||
              status == TelemetryStatus.serviceOff)
            GestureDetector(
              onTap: () => widget.telemetryService.startTracking(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: info.$3.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: info.$3.withOpacity(0.2)),
                ),
                child: Text(
                  'RETRY',
                  style: TextStyle(
                    color: info.$3,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1,
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
        color: const Color(0xFF0D1520),
        border: Border.all(
          color: const Color(0xFF00FFD1).withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFD1).withOpacity(0.03),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFD1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.satellite_alt,
                      color: Color(0xFF00FFD1), size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TELEMETRY',
                  style: TextStyle(
                    color: Color(0xFF00FFD1),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
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
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
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
                              Color(0xFF1A2535),
                              Color(0xFF243040),
                              Color(0xFF1A2535),
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
                      fontSize: 14,
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
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LOCATION NOTE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        TextField(
          controller: _noteController,
          onChanged: _onNoteChanged,
          style: const TextStyle(color: Color(0xFFE0E6ED), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g., Sanghavi Infotech, Japan, China',
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFD1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.edit_location_alt,
                  color: Color(0xFF00FFD1), size: 16),
            ),
            suffixIcon: _noteController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Colors.white.withOpacity(0.2), size: 16),
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
      _NavItem('System\nOverlay', Icons.layers,
          [const Color(0xFF00FFD1), const Color(0xFF00B4D8)], '/overlay'),
      _NavItem('Camera\nCapture', Icons.camera_alt,
          [const Color(0xFF6C63FF), const Color(0xFF3B82F6)], '/camera'),
      _NavItem('Stamp\nScreenshot', Icons.photo_filter,
          [const Color(0xFFFF4757), const Color(0xFFFF8E53)], '/stamper'),
      _NavItem('Speed\nTest', Icons.speed,
          [const Color(0xFF00C9A7), const Color(0xFF845EC2)], '/browser'),
      _NavItem('Zabbix\nMonitor', Icons.monitor_heart,
          [const Color(0xFF00B4D8), const Color(0xFF6C63FF)], '/zabbix'),
      _NavItem('Cyber\nPing', Icons.terminal,
          [const Color(0xFF00FF41), const Color(0xFF00FFD1)], '/ping'),
      _NavItem('Settings', Icons.tune,
          [const Color(0xFF3A4A5A), const Color(0xFF2A3A4A)], '/settings'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 110,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildAnimatedEntry(
          4 + index,
          _NavCard(
            item: items[index],
            onTap: () => Navigator.pushNamed(context, items[index].route)
                .then((_) => setState(() {})),
          ),
        );
      },
    );
  }

  Widget _buildFAB(bool isStreaming) {
    return AnimatedBuilder(
      animation: _fabGlowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isStreaming
                        ? const Color(0xFFFF4757)
                        : const Color(0xFF00FFD1))
                    .withOpacity(_fabGlowAnimation.value * 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _toggleTracking,
            backgroundColor: isStreaming
                ? const Color(0xFFFF4757)
                : const Color(0xFF00FFD1),
            foregroundColor:
                isStreaming ? Colors.white : const Color(0xFF080D14),
            elevation: 0,
            icon: Icon(isStreaming ? Icons.stop_circle : Icons.play_arrow),
            label: Text(
              isStreaming ? 'STOP GPS' : 'START GPS',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
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

class _NavCard extends StatefulWidget {
  final _NavItem item;
  final VoidCallback onTap;

  const _NavCard({required this.item, required this.onTap});

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF0D1520),
            border: Border.all(
              color: _isPressed
                  ? item.gradient[0].withOpacity(0.4)
                  : item.gradient[0].withOpacity(0.1),
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: item.gradient[0].withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
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
                  boxShadow: [
                    BoxShadow(
                      color: item.gradient[0].withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 16),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFFE0E6ED),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
