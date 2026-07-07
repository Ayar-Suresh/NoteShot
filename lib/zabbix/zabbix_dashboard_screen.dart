import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ZabbixDashboardScreen extends StatefulWidget {
  const ZabbixDashboardScreen({super.key});

  @override
  State<ZabbixDashboardScreen> createState() => _ZabbixDashboardScreenState();
}

class _ZabbixDashboardScreenState extends State<ZabbixDashboardScreen> {
  late WebViewController _webController;
  final TransformationController _transformController = TransformationController();
  bool _isLoading = true;

  // The custom NetForge Zabbix Theme!
  final String _customCss = '''
    /* General Backgrounds & Text */
    body, .article, .header-title, .wrapper, .setup-container, .signin-container { 
        background-color: #080D14 !important; 
        color: #E0E6ED !important; 
    }
    .layout-wrapper, .bg-info, .dashboard-grid {
        background-color: #080D14 !important; 
    }
    
    /* Links */
    a, .link-action, .link-alt { 
        color: #00FFD1 !important; 
    }
    
    /* Headers & Navigation */
    .top-nav-container, .header-navigation, .sidebar {
        background-color: #05080C !important;
        border-right: 1px solid #1A2535 !important;
    }
    
    /* Dashboard Widgets */
    .dashbrd-grid-widget-container, .dashbrd-grid-widget-head, .dashbrd-grid-widget-content {
        background-color: #0D1520 !important;
        border-color: #1A2535 !important;
        color: #E0E6ED !important;
    }
    
    /* Tables */
    table.list-table {
        border-collapse: collapse !important;
        background-color: #080D14 !important;
    }
    table.list-table thead th {
        background-color: #0D1520 !important;
        color: #00B4D8 !important;
        border-bottom: 2px solid #00FFD1 !important;
    }
    table.list-table tbody tr {
        background-color: #080D14 !important;
    }
    table.list-table tbody tr:hover td { 
        background-color: #1A2535 !important; 
    }
    table.list-table tbody tr td { 
        border-bottom: 1px solid #1A2535 !important; 
        color: #E0E6ED !important;
    }
    
    /* Buttons */
    .btn-alt, .btn, button, input[type="button"], input[type="submit"] { 
        background-color: #0D1520 !important; 
        border: 1px solid #00FFD1 !important; 
        color: #00FFD1 !important; 
        border-radius: 4px !important;
        box-shadow: 0 0 5px rgba(0, 255, 209, 0.2) !important;
    }
    .btn-alt:hover, .btn:hover, button:hover {
        background-color: #00FFD1 !important;
        color: #080D14 !important;
    }
    
    /* Inputs */
    input[type="text"], input[type="password"], select, textarea {
        background-color: #0D1520 !important;
        border: 1px solid #1A2535 !important;
        color: #00FFD1 !important;
    }
    input:focus {
        border-color: #00FFD1 !important;
        box-shadow: 0 0 5px rgba(0, 255, 209, 0.5) !important;
    }
    
    /* Problem Severities */
    .msg-bad { background-color: #FF4757 !important; color: white !important; border: none !important; }
    .msg-good { background-color: #00FFD1 !important; color: #080D14 !important; border: none !important; }
    .msg-warning { background-color: #FFA502 !important; color: white !important; border: none !important; }
    
    .na-bg { background-color: #0D1520 !important; color: #00FFD1 !important; }
    .info-bg { background-color: #00B4D8 !important; color: #080D14 !important; }
    .warning-bg { background-color: #FFA502 !important; color: white !important; }
    .average-bg { background-color: #FF6B6B !important; color: white !important; }
    .high-bg { background-color: #FF4757 !important; color: white !important; }
    .disaster-bg { background-color: #FF0000 !important; color: white !important; }
    
    /* Filters and Tabs */
    .filter-container { background-color: #0D1520 !important; border: 1px solid #1A2535 !important; }
    ul.ui-tabs-nav li { background-color: #0D1520 !important; border-bottom: none !important; }
    ul.ui-tabs-nav li.ui-tabs-active { background-color: #00FFD1 !important; }
    ul.ui-tabs-nav li.ui-tabs-active a { color: #080D14 !important; }
    
    /* Overlays and Popups */
    .overlay-dialogue {
        background-color: #0D1520 !important;
        border: 1px solid #00FFD1 !important;
        box-shadow: 0 0 15px rgba(0, 255, 209, 0.1) !important;
    }
  ''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            // Inject CSS to ensure dark theme matches
            final js = """
              var style = document.createElement('style');
              style.innerHTML = `${_customCss.replaceAll('\n', ' ')}`;
              document.head.appendChild(style);
            """;
            await _webController.runJavaScript(js);
            
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('http://43.252.198.181/zabbix'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D14),
      appBar: AppBar(
        title: const Text('ZABBIX MONITOR'),
        backgroundColor: const Color(0xFF0D1520),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FFD1)),
            onPressed: () {
              _webController.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFF00FFD1)),
            onPressed: () {
              _webController.loadRequest(Uri.parse('http://43.252.198.181/zabbix'));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Force a desktop resolution (e.g. 1280 width)
              const double targetWidth = 1280.0;
              // Calculate height maintaining the aspect ratio of the screen
              final double targetHeight = constraints.maxHeight * (targetWidth / constraints.maxWidth);
              
              // Set initial zoom out to fit the screen
              final double initialScale = constraints.maxWidth / targetWidth;
              _transformController.value = Matrix4.identity()..scale(initialScale);

              return InteractiveViewer(
                transformationController: _transformController,
                constrained: false,
                minScale: initialScale * 0.5,
                maxScale: 3.0,
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(
                  width: targetWidth,
                  height: targetHeight,
                  child: WebViewWidget(controller: _webController),
                ),
              );
            },
          ),
          
          if (_isLoading)
            Container(
              color: const Color(0xFF080D14).withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1520),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF00FFD1).withOpacity(0.1)),
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF00FFD1),
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'INJECTING NEON THEME...',
                      style: TextStyle(
                        color: const Color(0xFF00FFD1).withOpacity(0.5),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
