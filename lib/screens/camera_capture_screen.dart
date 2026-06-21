import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isFrontCamera = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initCamera();
    widget.telemetryService.addListener(_onTelemetryUpdate);
  }

  void _onTelemetryUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final cam = _cameras!.firstWhere(
        (c) => c.lensDirection == (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
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
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _cameraController!.takePicture();
      final imageBytes = await xFile.readAsBytes();

      // Capture the overlay HUD render tree as an image
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final hudImage = await boundary.toImage(pixelRatio: 3.0);
      final hudByteData = await hudImage.toByteData(format: ui.ImageByteFormat.png);
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
      final fileName = 'NoteShot_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(composedBytes);

      // Save to gallery
      await Gal.putImage(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A2735),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00E5CC), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved: $fileName',
                    style: const TextStyle(color: Color(0xFFE0E6ED)),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF6B6B),
            content: Text('Capture failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<Uint8List> _composeImages(Uint8List cameraBytes, Uint8List hudBytes) async {
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
    final size = Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    // Draw camera image
    canvas.drawImage(cameraImage, Offset.zero, Paint());

    // Draw HUD at bottom-left with some padding
    final hudScale = size.width / (hudOverlay.width * 1.2);
    final hudMatrix = Matrix4.identity()
      ..translate(size.width * 0.02, size.height - (hudOverlay.height * hudScale) - size.height * 0.02)
      ..scale(hudScale);

    canvas.save();
    canvas.transform(hudMatrix.storage);
    canvas.drawImage(hudOverlay, Offset.zero, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(cameraImage.width, cameraImage.height);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  @override
  void dispose() {
    widget.telemetryService.removeListener(_onTelemetryUpdate);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetryService.telemetry;
    final storage = widget.storageService;
    final use24 = storage.use24Hour;
    final displayMap = telemetry.toDisplayMap(use24Hour: use24);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('CAMERA CAPTURE'),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_isInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 100,
                  height: 100 / _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E5CC)),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Color(0xFF556677)),
                  ),
                ],
              ),
            ),

          // Telemetry HUD Overlay (wrapped in RepaintBoundary for capture)
          Positioned(
            left: 12,
            bottom: 100,
            child: RepaintBoundary(
              key: _repaintKey,
              child: _buildHUD(displayMap, storage),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCaptureButton(),
            ),
          ),

          // Loading overlay
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF00E5CC),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Stamping image...',
                      style: TextStyle(
                        color: Color(0xFFE0E6ED),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
      const Color(0xFF00E5CC),
      const Color(0xFFFFFFFF),
      const Color(0xFFFFD700),
      const Color(0xFF00FF88),
      const Color(0xFFFF6B6B),
    ];
    final textColor = textColors[storage.textColorIndex.clamp(0, textColors.length - 1)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(bgOpacity),
        borderRadius: BorderRadius.circular(4),
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
                color: textColor == const Color(0xFFFFFFFF) ? Colors.black : textColor,
                fontWeight: FontWeight.w600,
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

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _captureAndStamp,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
