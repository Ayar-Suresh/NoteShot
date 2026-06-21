import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/telemetry_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/overlay_launch_screen.dart';
import 'screens/camera_capture_screen.dart';
import 'screens/screenshot_stamper_screen.dart';
import 'screens/browser_test_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ping_screen.dart';
import 'zabbix/zabbix_dashboard_screen.dart';
import 'overlay/overlay_entry.dart';

late StorageService storageService;
late TelemetryService telemetryService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  storageService = StorageService();
  await storageService.init();
  telemetryService = TelemetryService();
  runApp(const NetForgeApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayEntryWidget(),
  ));
}

class NetForgeApp extends StatelessWidget {
  const NetForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D14),
        canvasColor: const Color(0xFF080D14),
        primaryColor: const Color(0xFF00FFD1),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFD1),
          secondary: Color(0xFF00B4D8),
          tertiary: Color(0xFFFF006E),
          surface: Color(0xFF0D1520),
          error: Color(0xFFFF4757),
          onPrimary: Color(0xFF080D14),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFFE0E6ED),
          onError: Color(0xFFFFFFFF),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0D1520),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF00FFD1).withOpacity(0.08),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080D14),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF00FFD1),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            fontFamily: 'monospace',
          ),
          iconTheme: IconThemeData(color: Color(0xFF00FFD1)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFD1),
            foregroundColor: const Color(0xFF080D14),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1520),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF00FFD1).withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF00FFD1).withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00FFD1), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF5A6A7A)),
          hintStyle: const TextStyle(color: Color(0xFF3A4A5A)),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF00FFD1),
          inactiveTrackColor: const Color(0xFF1A2535),
          thumbColor: const Color(0xFF00FFD1),
          overlayColor: const Color(0xFF00FFD1).withOpacity(0.15),
          trackHeight: 3,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00FFD1);
            }
            return const Color(0xFF3A4A5A);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00FFD1).withOpacity(0.3);
            }
            return const Color(0xFF1A2535);
          }),
        ),
        dividerColor: const Color(0xFF1A2535),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => DashboardScreen(
              telemetryService: telemetryService,
              storageService: storageService,
            ),
        '/overlay': (context) => OverlayLaunchScreen(
              telemetryService: telemetryService,
              storageService: storageService,
            ),
        '/camera': (context) => CameraCaptureScreen(
              telemetryService: telemetryService,
              storageService: storageService,
            ),
        '/stamper': (context) => ScreenshotStamperScreen(
              telemetryService: telemetryService,
              storageService: storageService,
            ),
        '/browser': (context) => BrowserTestScreen(
              telemetryService: telemetryService,
              storageService: storageService,
            ),
        '/settings': (context) => SettingsScreen(
              storageService: storageService,
            ),
        '/ping': (context) => const PingScreen(),
        '/zabbix': (context) => const ZabbixDashboardScreen(),
      },
    );
  }
}
