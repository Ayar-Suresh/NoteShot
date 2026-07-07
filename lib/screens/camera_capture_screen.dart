import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../services/telemetry_service.dart';
import '../services/storage_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  final TelemetryService telemetryService;
  final StorageService storageService;

  const CameraCaptureScreen({
    super.key,
    required this.telemetryService,
    required this.storageService,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isFrontCamera = false;
  final GlobalKey _repaintKey = GlobalKey();

  // Animations
  late AnimationController _pulseController;
  late AnimationController _cornerController;
  late AnimationController _flashController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _cornerAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    widget.telemetryService.addListener(_onTelemetryUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _cornerAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeInOut),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGpsStatus();
    });
  }

  Future<void> _checkGpsStatus() async {
    final status = widget.telemetryService.status;
    if (status == TelemetryStatus.idle || 
        status == TelemetryStatus.serviceOff || 
        status == TelemetryStatus.denied) {
      await widget.telemetryService.startTracking();
    }
    
    if (mounted && widget.telemetryService.status == TelemetryStatus.serviceOff) {
      _showEnableGpsPrompt();
    }
  }

  void _showEnableGpsPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFFF4757).withOpacity(0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Color(0xFFFF4757)),
            const SizedBox(width: 10),
            const Text('GPS is Disabled', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Realtime telemetry requires GPS to be enabled. Please turn on Location Services in your settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Ignore', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFD1),
              foregroundColor: const Color(0xFF080D14),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.telemetryService.openLocationSettings();
            },
            child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onTelemetryUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final cam = _cameras!.firstWhere(
        (c) => c.lensDirection ==
            (_isFrontCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    _isFrontCamera = !_isFrontCamera;
    _isInitialized = false;
    await _cameraController?.dispose();
    setState(() {});
    await _initCamera();
  }

  Future<void> _captureAndStamp() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);

    // Trigger flash animation
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final xFile = await _cameraController!.takePicture();
      final imageBytes = await xFile.readAsBytes();

      // Capture the overlay HUD render tree as an image
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final hudImage = await boundary.toImage(pixelRatio: 3.0);
      final hudByteData =
          await hudImage.toByteData(format: ui.ImageByteFormat.png);
      if (hudByteData == null) {
        setState(() => _isCapturing = false);
        return;
      }

      // Compose the camera photo with the HUD overlay
      final composedBytes = await _composeImages(
        imageBytes,
        hudByteData.buffer.asUint8List(),
      );

      // Save to temporary directory first
      final dir = await getTemporaryDirectory();
      final fileName =
          'NetForge_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(composedBytes);

      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Storage permission denied');
        }
      }

      // Save to gallery
      await Gal.putImage(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D1520),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFD1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF00FFD1), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capture saved',
                        style: TextStyle(
                          color: Color(0xFF00FFD1),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        fileName,
                        style: TextStyle(
                          color: const Color(0xFFE0E6ED).withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: const Color(0xFF00FFD1).withOpacity(0.2)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF4757),
            content: Text('Capture failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<Uint8List> _composeImages(
      Uint8List cameraBytes, Uint8List hudBytes) async {
    // Decode camera image
    final cameraCodec = await ui.instantiateImageCodec(cameraBytes);
    final cameraFrame = await cameraCodec.getNextFrame();
    final cameraImage = cameraFrame.image;

    // Decode HUD image
    final hudCodec = await ui.instantiateImageCodec(hudBytes);
    final hudFrame = await hudCodec.getNextFrame();
    final hudOverlay = hudFrame.image;

    // Create a canvas and compose
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    // Draw camera image
    canvas.drawImage(cameraImage, Offset.zero, Paint());

    // Draw HUD at bottom-left with some padding
    final hudScale = (size.width * 0.45) / hudOverlay.width; // 45% of image width
    final hudMatrix = Matrix4.identity()
      ..translate(size.width * 0.03,
          size.height - (hudOverlay.height * hudScale) - size.height * 0.03)
      ..scale(hudScale);

    canvas.save();
    canvas.transform(hudMatrix.storage);
    canvas.drawImage(hudOverlay, Offset.zero, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final finalImage =
        await picture.toImage(cameraImage.width, cameraImage.height);
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  @override
  void dispose() {
    widget.telemetryService.removeListener(_onTelemetryUpdate);
    _cameraController?.dispose();
    _pulseController.dispose();
    _cornerController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetryService.telemetry;
    final storage = widget.storageService;
    final use24 = storage.use24Hour;
    final useIST = storage.useIST;
    final displayMap = telemetry.toDisplayMap(use24Hour: use24, useIST: useIST);

    return Scaffold(
      backgroundColor: const Color(0xFF080D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('CAMERA CAPTURE'),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFD1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00FFD1).withOpacity(0.2)),
                ),
                child: const Icon(Icons.flip_camera_android, size: 20),
              ),
              onPressed: _switchCamera,
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview — FIXED: proper aspect ratio handling
          if (_isInitialized && _cameraController != null)
            Builder(
              builder: (context) {
                final isPortrait = MediaQuery.of(context).orientation ==
                    Orientation.portrait;
                final double cameraRatio =
                    _cameraController!.value.aspectRatio;
                
                // Camera plugin often returns landscape ratio (e.g. 1.77) even in portrait.
                // We ensure the ratio correctly matches the current device orientation.
                final double ratio = isPortrait
                    ? (cameraRatio > 1 ? (1 / cameraRatio) : cameraRatio)
                    : (cameraRatio < 1 ? (1 / cameraRatio) : cameraRatio);

                return Center(
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: CameraPreview(_cameraController!),
                  ),
                );
              },
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1520),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00FFD1).withOpacity(0.15),
                      ),
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF00FFD1),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(
                      color: const Color(0xFF00FFD1).withOpacity(0.5),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Neon viewfinder corners
          if (_isInitialized)
            AnimatedBuilder(
              animation: _cornerAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ViewfinderPainter(
                    opacity: _cornerAnimation.value,
                    color: const Color(0xFF00FFD1),
                  ),
                  size: Size.infinite,
                );
              },
            ),

          // Telemetry HUD Overlay
          Positioned(
            left: 12,
            bottom: 110 + MediaQuery.of(context).padding.bottom,
            child: RepaintBoundary(
              key: _repaintKey,
              child: _buildHUD(displayMap, storage),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCaptureButton(),
            ),
          ),

          // Capture flash effect
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              if (_flashAnimation.value == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Container(
                  color: const Color(0xFF00FFD1)
                      .withOpacity(_flashAnimation.value * 0.3),
                ),
              );
            },
          ),

          // Loading overlay
          if (_isCapturing)
            Container(
              color: const Color(0xFF080D14).withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1520),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00FFD1).withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFD1).withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF00FFD1),
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'STAMPING IMAGE...',
                      style: TextStyle(
                        color: Color(0xFF00FFD1),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
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

  Widget _buildHUD(Map<String, String> displayMap, StorageService storage) {
    final double fontSize = storage.fontSize;
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(bgOpacity * 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: textColor.withOpacity(0.2),
            width: 0.5,
          ),
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
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 4,
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
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _captureAndStamp,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFD1)
                      .withOpacity(_pulseAnimation.value * 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00FFD1)
                      .withOpacity(0.6 + _pulseAnimation.value * 0.4),
                  width: 3,
                ),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00FFD1),
                        const Color(0xFF00FFD1).withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.camera,
                    color: Color(0xFF080D14),
                    size: 28,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Neon viewfinder corners painter
class _ViewfinderPainter extends CustomPainter {
  final double opacity;
  final Color color;

  _ViewfinderPainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const margin = 40.0;
    const len = 30.0;

    // Top-left
    canvas.drawLine(
        Offset(margin, margin), Offset(margin + len, margin), paint);
    canvas.drawLine(
        Offset(margin, margin), Offset(margin, margin + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin, margin),
        Offset(size.width - margin - len, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin),
        Offset(size.width - margin, margin + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin),
        Offset(margin + len, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin),
        Offset(margin, size.height - margin - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - margin, size.height - margin),
        Offset(size.width - margin - len, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin),
        Offset(size.width - margin, size.height - margin - len), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
