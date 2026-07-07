import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/telemetry_service.dart';
import '../services/storage_service.dart';

class BrowserTestScreen extends StatefulWidget {
  final TelemetryService telemetryService;
  final StorageService storageService;

  const BrowserTestScreen({
    super.key,
    required this.telemetryService,
    required this.storageService,
  });

  @override
  State<BrowserTestScreen> createState() => _BrowserTestScreenState();
}

class _BrowserTestScreenState extends State<BrowserTestScreen>
    with SingleTickerProviderStateMixin {
  late WebViewController _webController;
  bool _isLoading = true;
  String _currentUrl = 'https://www.nperf.com/en/';
  Offset _hudOffset = const Offset(10, 10);
  bool _showHud = true;
  late AnimationController _loadingBarController;

  final List<_SpeedSite> _sites = [
    _SpeedSite('Fast.com', 'https://fast.com', Icons.bolt),
    _SpeedSite('Speedtest.net', 'https://www.speedtest.net', Icons.speed),
  ];

  @override
  void initState() {
    super.initState();
    widget.telemetryService.addListener(_onUpdate);

    _loadingBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initWebView();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    if (widget.storageService.useMockLocation) {
      await widget.telemetryService.startTracking();
      return;
    }

    final status = widget.telemetryService.status;
    if (status == TelemetryStatus.denied || status == TelemetryStatus.serviceOff || status == TelemetryStatus.idle) {
      await widget.telemetryService.startTracking();
      if (widget.telemetryService.status == TelemetryStatus.denied || widget.telemetryService.status == TelemetryStatus.serviceOff) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0D1520),
              title: const Text('Location Required', style: TextStyle(color: Color(0xFF00FFD1))),
              content: const Text('Please enable location services for speed test stamping.', style: TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    widget.telemetryService.openLocationSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('OPEN SETTINGS'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _loadSite(String url) {
    setState(() {
      _currentUrl = url;
      _isLoading = true;
    });
    _webController.loadRequest(Uri.parse(url));
  }

  void _showAddCustomDialog() {
    final controller = TextEditingController(text: 'https://');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: const Color(0xFF00FFD1).withOpacity(0.1)),
        ),
        title: const Text('Add Custom Speed Test URL',
            style: TextStyle(
                color: Color(0xFF00FFD1),
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: Colors.white24),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                widget.storageService.addCustomUrl(url).then((_) {
                  setState(() {});
                  _loadSite(url);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('ADD',
                style: TextStyle(
                    color: Color(0xFF00FFD1),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.telemetryService.removeListener(_onUpdate);
    _loadingBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetryService.telemetry;
    final storage = widget.storageService;
    final displayMap = telemetry.toDisplayMap(use24Hour: storage.use24Hour);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPEED TEST'),
        actions: [
          // Site selector
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFD1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.public, size: 18),
            ),
            color: const Color(0xFF0D1520),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: const Color(0xFF00FFD1).withOpacity(0.1)),
            ),
            onSelected: (val) {
              if (val == '__ADD_CUSTOM__') {
                _showAddCustomDialog();
              } else {
                _loadSite(val);
              }
            },
            itemBuilder: (context) {
              final allUrls = [
                ..._sites,
                ...widget.storageService.customUrls
                    .map((url) => _SpeedSite('Custom', url, Icons.public)),
              ];

              final items = allUrls.map((site) {
                return PopupMenuItem(
                  value: site.url,
                  child: Row(
                    children: [
                      Icon(site.icon,
                          color: site.url == _currentUrl
                              ? const Color(0xFF00FFD1)
                              : Colors.white54,
                          size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              site.name +
                                  (site.name == 'Custom'
                                      ? ': ${site.url}'
                                      : ''),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList();

              items.add(const PopupMenuItem(
                value: '__ADD_CUSTOM__',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Color(0xFF00FFD1), size: 18),
                    SizedBox(width: 10),
                    Text('Add Custom Site',
                        style: TextStyle(color: Color(0xFF00FFD1))),
                  ],
                ),
              ));

              return items;
            },
          ),
          // Toggle HUD
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _showHud
                    ? const Color(0xFF00FFD1).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _showHud ? Icons.visibility : Icons.visibility_off,
                color: _showHud
                    ? const Color(0xFF00FFD1)
                    : Colors.white38,
                size: 18,
              ),
            ),
            onPressed: () => setState(() => _showHud = !_showHud),
          ),
          // Reload
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _webController.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _webController),

          // Animated loading bar
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _loadingBarController,
                builder: (context, child) {
                  return Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(
                            -1.0 + 2.0 * _loadingBarController.value, 0),
                        end: Alignment(
                            1.0 + 2.0 * _loadingBarController.value, 0),
                        colors: const [
                          Color(0xFF080D14),
                          Color(0xFF00FFD1),
                          Color(0xFF00B4D8),
                          Color(0xFF080D14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Floating HUD
          if (_showHud)
            Positioned(
              left: _hudOffset.dx,
              top: _hudOffset.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    final size = MediaQuery.of(context).size;
                    _hudOffset = Offset(
                      (_hudOffset.dx + details.delta.dx)
                          .clamp(0, size.width - 100),
                      (_hudOffset.dy + details.delta.dy)
                          .clamp(0, size.height - 200),
                    );
                  });
                },
                child: _buildHud(displayMap, storage),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHud(
      Map<String, String> displayMap, StorageService storage) {
    final double fontSize = storage.fontSize * 0.8;
    final double bgOpacity = storage.bgOpacity;
    final lines = <String>[];

    if (storage.showLat) lines.add('Latitude:  ${displayMap['Lat']}');
    if (storage.showLon) lines.add('Longitude: ${displayMap['Lon']}');
    if (storage.showElev) lines.add('Elevation: ${displayMap['Elev']}');
    if (storage.showAccuracy) lines.add('Accuracy:  ${displayMap['Acc']}');
    if (storage.showTime) lines.add('Time:      ${displayMap['Time']}');
    if (storage.showNotes && storage.noteText.isNotEmpty) {
      lines.add('Note:      ${storage.noteText}');
    }

    final textColors = [
      const Color(0xFF00FFD1),
      const Color(0xFFFFFFFF),
      const Color(0xFFFFD700),
      const Color(0xFF00FF88),
      const Color(0xFFFF6B6B),
    ];
    final textColor =
        textColors[storage.textColorIndex.clamp(0, textColors.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(bgOpacity * 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: fontSize,
                    color: textColor == const Color(0xFFFFFFFF)
                        ? Colors.white
                        : textColor,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Geniusly crafted by Ayar Suresh 😎',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize * 0.75,
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedSite {
  final String name;
  final String url;
  final IconData icon;
  _SpeedSite(this.name, this.url, this.icon);
}
