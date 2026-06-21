import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../services/telemetry_service.dart';
import '../services/storage_service.dart';

class ScreenshotStamperScreen extends StatefulWidget {
  final TelemetryService telemetryService;
  final StorageService storageService;

  const ScreenshotStamperScreen({
    super.key,
    required this.telemetryService,
    required this.storageService,
  });

  @override
  State<ScreenshotStamperScreen> createState() => _ScreenshotStamperScreenState();
}

class _ScreenshotStamperScreenState extends State<ScreenshotStamperScreen> {
  File? _selectedImage;
  Offset _watermarkOffset = const Offset(20, 20);
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSaving = false;
  Size _imageDisplaySize = Size.zero;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _watermarkOffset = const Offset(20, 20);
      });
    }
  }

  Future<void> _saveStampedImage() async {
    if (_selectedImage == null) return;
    setState(() => _isSaving = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSaving = false);
        return;
      }

      final wmImage = await boundary.toImage(pixelRatio: 3.0);
      final wmByteData = await wmImage.toByteData(format: ui.ImageByteFormat.png);
      final wmBytes = wmByteData!.buffer.asUint8List();

      final bgBytes = await _selectedImage!.readAsBytes();
      final composedBytes = await _composeImages(bgBytes, wmBytes, _watermarkOffset, _imageDisplaySize);

      final dir = await getTemporaryDirectory();
      final fileName = 'NoteShot_Stamp_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(composedBytes);

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
                  child: Text('Saved: $fileName',
                      style: const TextStyle(color: Color(0xFFE0E6ED))),
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
            content: Text('Save failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _composeImages(Uint8List bgBytes, Uint8List wmBytes, Offset offset, Size containerSize) async {
    final bgCodec = await ui.instantiateImageCodec(bgBytes);
    final bgFrame = await bgCodec.getNextFrame();
    final bgImage = bgFrame.image;

    final wmCodec = await ui.instantiateImageCodec(wmBytes);
    final wmFrame = await wmCodec.getNextFrame();
    final wmImage = wmFrame.image;

    final bgSize = Size(bgImage.width.toDouble(), bgImage.height.toDouble());
    double containerAspect = containerSize.width / containerSize.height;
    double imageAspect = bgSize.width / bgSize.height;

    double renderWidth, renderHeight;
    if (containerAspect > imageAspect) {
      renderHeight = containerSize.height;
      renderWidth = renderHeight * imageAspect;
    } else {
      renderWidth = containerSize.width;
      renderHeight = renderWidth / imageAspect;
    }

    double dx = (containerSize.width - renderWidth) / 2;
    double dy = (containerSize.height - renderHeight) / 2;

    final scale = bgSize.width / renderWidth;
    final relX = offset.dx - dx;
    final relY = offset.dy - dy;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(bgImage, Offset.zero, Paint());

    final wmMatrix = Matrix4.identity()
      ..translate(relX * scale, relY * scale)
      ..scale(scale);

    canvas.save();
    canvas.transform(wmMatrix.storage);
    canvas.drawImage(wmImage, Offset.zero, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(bgImage.width, bgImage.height);
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetryService.telemetry;
    final storage = widget.storageService;
    final displayMap = telemetry.toDisplayMap(use24Hour: storage.use24Hour);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'STAMP SCREENSHOT',
          style: TextStyle(
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        iconTheme: const IconThemeData(
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
        actions: [
          if (_selectedImage != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00E5CC)),
                    )
                  : const Icon(Icons.save_alt),
              onPressed: _isSaving ? null : _saveStampedImage,
            ),
        ],
      ),
      body: _selectedImage == null ? _buildEmptyState() : _buildEditor(displayMap, storage),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        backgroundColor: const Color(0xFF00E5CC),
        foregroundColor: const Color(0xFF0F1923),
        icon: const Icon(Icons.image),
        label: Text(
          _selectedImage == null ? 'SELECT IMAGE' : 'CHANGE IMAGE',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2735),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A3A4A)),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Import a screenshot to stamp',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GPS telemetry will be burned onto the image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(Map<String, String> displayMap, StorageService storage) {
    return Column(
      children: [
        // Hint bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF00E5CC).withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF00E5CC), size: 16),
              const SizedBox(width: 8),
              Text(
                'Drag the watermark to reposition it',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Image canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _imageDisplaySize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                  // Draggable watermark
                  Positioned(
                    left: _watermarkOffset.dx,
                    top: _watermarkOffset.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _watermarkOffset = Offset(
                            (_watermarkOffset.dx + details.delta.dx)
                                .clamp(0, _imageDisplaySize.width - 50),
                            (_watermarkOffset.dy + details.delta.dy)
                                .clamp(0, _imageDisplaySize.height - 50),
                          );
                        });
                      },
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: _buildWatermark(displayMap, storage),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWatermark(Map<String, String> displayMap, StorageService storage) {
    // Make font size smaller so the watermark is more manageable on screen
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
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
}
