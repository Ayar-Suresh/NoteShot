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
  runApp(const NoteShotApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayEntryWidget(),
  ));
}

class NoteShotApp extends StatelessWidget {
  const NoteShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteShot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        canvasColor: const Color(0xFF0F1923),
        primaryColor: const Color(0xFF00E5CC),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5CC),
          secondary: Color(0xFF00B4D8),
          surface: Color(0xFF1A2735),
          error: Color(0xFFFF6B6B),
          onPrimary: Color(0xFF0F1923),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFFE0E6ED),
          onError: Color(0xFFFFFFFF),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A2735),
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1923),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF00E5CC),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00E5CC)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5CC),
            foregroundColor: const Color(0xFF0F1923),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A2735),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A3A4A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00E5CC), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8899AA)),
          hintStyle: const TextStyle(color: Color(0xFF556677)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF00E5CC),
          inactiveTrackColor: Color(0xFF2A3A4A),
          thumbColor: Color(0xFF00E5CC),
          overlayColor: Color(0x3300E5CC),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00E5CC);
            }
            return const Color(0xFF556677);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00E5CC).withOpacity(0.4);
            }
            return const Color(0xFF2A3A4A);
          }),
        ),
        dividerColor: const Color(0xFF2A3A4A),
        useMaterial3: true,
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
