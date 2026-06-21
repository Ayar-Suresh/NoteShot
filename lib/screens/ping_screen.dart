import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';

class TerminalLine {
  final TextSpan content;
  final bool isSuccess;
  final bool isError;
  TerminalLine(this.content, {this.isSuccess = false, this.isError = false});
}

class PingScreen extends StatefulWidget {
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> with TickerProviderStateMixin {
  final TextEditingController _targetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Ping? _ping;
  StreamSubscription? _pingSubscription;
  final List<TerminalLine> _outputLines = [];
  bool _isRunning = false;
  bool _isIpMode = true;

  // Animations
  late AnimationController _cursorController;
  late AnimationController _scanlineController;
  late AnimationController _matrixController;
  late AnimationController _glowController;
  late Animation<double> _cursorAnimation;
  late Animation<double> _scanlineAnimation;
  late Animation<double> _glowAnimation;

  // Track new line animations
  final Map<int, AnimationController> _lineAnimations = {};

  @override
  void initState() {
    super.initState();

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _cursorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_cursorController);

    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _scanlineAnimation = Tween<double>(begin: -0.1, end: 1.1).animate(
      CurvedAnimation(parent: _scanlineController, curve: Curves.linear),
    );

    _matrixController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _printMotd();
  }

  void _printMotd() {
    _outputLines.addAll([
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(TextSpan(
        children: [
          _span('  ▓▓▓ ', const Color(0xFF00FFD1)),
          _span('NETFORGE PING TERMINAL', const Color(0xFF00FF41)),
          _span(' v2.0 ▓▓▓', const Color(0xFF00FFD1)),
        ],
      )),
      TerminalLine(_span('  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', const Color(0xFF00FFD1).withOpacity(0.4))),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(TextSpan(
        children: [
          _span('  ◈ ', const Color(0xFF00FFD1)),
          _span('Packet engine initialized', const Color(0xFF8899AA)),
        ],
      )),
      TerminalLine(TextSpan(
        children: [
          _span('  ◈ ', const Color(0xFF00FFD1)),
          _span('ICMP socket ready', const Color(0xFF8899AA)),
        ],
      )),
      TerminalLine(TextSpan(
        children: [
          _span('  ◈ ', const Color(0xFF00FFD1)),
          _span('Network interface active', const Color(0xFF8899AA)),
        ],
      )),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(TextSpan(
        children: [
          _span('  Engineered by ', const Color(0xFF556677)),
          _span('Ayar Suresh', const Color(0xFF00FFD1)),
          _span(' // ', const Color(0xFF556677)),
          _span('NetForge', const Color(0xFF00FF41)),
        ],
      )),
      TerminalLine(_span('  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', const Color(0xFF00FFD1).withOpacity(0.4))),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(TextSpan(
        children: [
          _span('  Type a target ', const Color(0xFF556677)),
          _span('IP', const Color(0xFF00FFD1)),
          _span(' or ', const Color(0xFF556677)),
          _span('domain', const Color(0xFF00FFD1)),
          _span(' to begin packet trace.', const Color(0xFF556677)),
        ],
      )),
      TerminalLine(_span('', Colors.transparent)),
    ]);
  }

  TextSpan _span(String text, Color color) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontSize: 12.5,
        height: 1.4,
        letterSpacing: 0.3,
      ),
    );
  }

  TextSpan _promptSpanWithCommand(String cmd) {
    return TextSpan(
      children: [
        _span('  ┌──(', const Color(0xFF00B4D8)),
        _span('ayar㉿netforge', const Color(0xFF00FFD1)),
        _span(')-[', const Color(0xFF00B4D8)),
        _span('~', Colors.white),
        _span(']\n  └─\$ ', const Color(0xFF00B4D8)),
        _span(cmd, const Color(0xFFE0E6ED)),
      ],
    );
  }

  void _addAnimatedLine(TerminalLine line) {
    final index = _outputLines.length;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _lineAnimations[index] = controller;
    _outputLines.add(line);
    controller.forward();
  }

  @override
  void dispose() {
    _targetController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pingSubscription?.cancel();
    _ping?.stop();
    _cursorController.dispose();
    _scanlineController.dispose();
    _matrixController.dispose();
    _glowController.dispose();
    for (final c in _lineAnimations.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _startPing() async {
    if (_targetController.text.trim().isEmpty) return;

    String target = _targetController.text.trim();
    if (target.startsWith('http://')) target = target.replaceFirst('http://', '');
    if (target.startsWith('https://')) target = target.replaceFirst('https://', '');
    if (target.endsWith('/')) target = target.substring(0, target.length - 1);
    if (target.contains('/')) target = target.split('/').first;

    setState(() {
      _isRunning = true;
      _outputLines.add(TerminalLine(_promptSpanWithCommand('ping $target')));
      _outputLines.add(TerminalLine(TextSpan(
        children: [
          _span('  PING ', const Color(0xFF00B4D8)),
          _span(target, const Color(0xFFE0E6ED)),
          _span(': 56 data bytes', const Color(0xFF556677)),
        ],
      )));
      _targetController.clear();
    });
    _scrollToBottom();

    _ping = Ping(target);
    _pingSubscription = _ping!.stream.listen((event) {
      if (mounted) {
        setState(() {
          if (event.response != null) {
            final r = event.response!;
            if (r.time != null) {
              _addAnimatedLine(TerminalLine(
                TextSpan(
                  children: [
                    _span('  ● ', const Color(0xFF00FF41)),
                    _span('64 bytes from ', const Color(0xFF8899AA)),
                    _span(target, const Color(0xFFE0E6ED)),
                    _span(': seq=', const Color(0xFF8899AA)),
                    _span('${r.seq}', const Color(0xFF00B4D8)),
                    _span(' time=', const Color(0xFF8899AA)),
                    _span('${r.time!.inMilliseconds}ms', const Color(0xFF00FF41)),
                  ],
                ),
                isSuccess: true,
              ));
            } else {
              _addAnimatedLine(TerminalLine(
                TextSpan(
                  children: [
                    _span('  ✖ ', const Color(0xFFFF4757)),
                    _span('Request timeout ', const Color(0xFFFF4757)),
                    _span('seq=', const Color(0xFF8899AA)),
                    _span('${r.seq}', const Color(0xFFFF6B6B)),
                  ],
                ),
                isError: true,
              ));
            }
          } else if (event.summary != null) {
            final s = event.summary!;
            final lossPercent = s.transmitted > 0
                ? ((s.transmitted - s.received) / s.transmitted * 100).round()
                : 0;
            final lossColor = lossPercent == 0
                ? const Color(0xFF00FF41)
                : lossPercent < 50
                    ? const Color(0xFFFFAA00)
                    : const Color(0xFFFF4757);

            _outputLines.add(TerminalLine(_span('', Colors.transparent)));
            _outputLines.add(TerminalLine(TextSpan(
              children: [
                _span('  ╔═══════════════════════════════════╗', const Color(0xFF00B4D8).withOpacity(0.5)),
              ],
            )));
            _outputLines.add(TerminalLine(TextSpan(
              children: [
                _span('  ║ ', const Color(0xFF00B4D8).withOpacity(0.5)),
                _span('PING STATISTICS — ', const Color(0xFF00FFD1)),
                _span(target, const Color(0xFFE0E6ED)),
                _span((' ' * max(0, 18 - target.length)), Colors.transparent),
                _span(' ║', const Color(0xFF00B4D8).withOpacity(0.5)),
              ],
            )));
            _outputLines.add(TerminalLine(TextSpan(
              children: [
                _span('  ╠═══════════════════════════════════╣', const Color(0xFF00B4D8).withOpacity(0.5)),
              ],
            )));
            _outputLines.add(TerminalLine(TextSpan(
              children: [
                _span('  ║ ', const Color(0xFF00B4D8).withOpacity(0.5)),
                _span(' TX: ', const Color(0xFF556677)),
                _span('${s.transmitted}', const Color(0xFF00FFD1)),
                _span('  RX: ', const Color(0xFF556677)),
                _span('${s.received}', const Color(0xFF00FF41)),
                _span('  LOSS: ', const Color(0xFF556677)),
                _span('$lossPercent%', lossColor),
                _span((' ' * max(0, 16 - '${s.transmitted}'.length - '${s.received}'.length - '$lossPercent'.length)), Colors.transparent),
                _span(' ║', const Color(0xFF00B4D8).withOpacity(0.5)),
              ],
            )));
            _outputLines.add(TerminalLine(TextSpan(
              children: [
                _span('  ╚═══════════════════════════════════╝', const Color(0xFF00B4D8).withOpacity(0.5)),
              ],
            )));
            _outputLines.add(TerminalLine(_span('', Colors.transparent)));
          } else if (event.error != null) {
            _addAnimatedLine(TerminalLine(
              TextSpan(
                children: [
                  _span('  ✖ ', const Color(0xFFFF4757)),
                  _span('ERROR: ', const Color(0xFFFF4757)),
                  _span('${event.error}', const Color(0xFFFF6B6B)),
                ],
              ),
              isError: true,
            ));
          }
        });
        _scrollToBottom();
      }
    });
  }

  void _stopPing() {
    _ping?.stop();
    _pingSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _outputLines.add(TerminalLine(TextSpan(
          children: [
            _span('  ', Colors.transparent),
            _span('^C', const Color(0xFFFF4757)),
            _span(' — interrupted', const Color(0xFF556677)),
          ],
        )));
      });
      _scrollToBottom();
      _focusNode.requestFocus();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1018),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRunning
                        ? Color.lerp(const Color(0xFF00FF41), const Color(0xFF00FF41).withOpacity(0.3), 1 - _glowAnimation.value)
                        : const Color(0xFF00FFD1).withOpacity(0.5),
                    boxShadow: _isRunning
                        ? [BoxShadow(color: const Color(0xFF00FF41).withOpacity(_glowAnimation.value * 0.6), blurRadius: 8)]
                        : [],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              _isRunning ? 'ayar@netforge:~# PINGING...' : 'ayar@netforge:~#',
              style: const TextStyle(
                color: Color(0xFF00FFD1),
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_isRunning)
            Tooltip(
              message: 'Send SIGINT (^C)',
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '^C',
                      style: TextStyle(
                        color: Color(0xFFFF4757),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onPressed: _stopPing,
                ),
              ),
            ),
          Tooltip(
            message: _isIpMode ? 'Switch to Domain' : 'Switch to IP',
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isIpMode ? 'IP' : 'DNS',
                  style: const TextStyle(
                    color: Color(0xFF00B4D8),
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isIpMode = !_isIpMode;
                  if (!_isRunning) {
                    _focusNode.unfocus();
                    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          _isIpMode ? Icons.pin_outlined : Icons.language,
                          color: const Color(0xFF00FFD1),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isIpMode ? 'Keyboard: IP Address' : 'Keyboard: Domain Name',
                          style: const TextStyle(
                            color: Color(0xFFE0E6ED),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFF0D1520),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFF00FFD1).withOpacity(0.2)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (!_isRunning) _focusNode.requestFocus();
        },
        child: Stack(
          children: [
            // Matrix rain background (very subtle)
            AnimatedBuilder(
              animation: _matrixController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MatrixRainPainter(_matrixController.value),
                  size: Size.infinite,
                );
              },
            ),

            // Terminal content
            Column(
              children: [
                // Top neon line
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF00FFD1).withOpacity(0.3),
                        const Color(0xFF00B4D8).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    itemCount: _outputLines.length + 1,
                    itemBuilder: (context, index) {
                      if (index < _outputLines.length) {
                        final line = _outputLines[index];
                        final animController = _lineAnimations[index];

                        Widget lineWidget = Padding(
                          padding: const EdgeInsets.only(bottom: 1.0),
                          child: RichText(text: line.content),
                        );

                        // Wrap with glow animation for success/error lines
                        if (animController != null) {
                          lineWidget = AnimatedBuilder(
                            animation: animController,
                            builder: (context, child) {
                              final value = animController.value;
                              final glowOpacity = (1.0 - value) * 0.4;

                              if (line.isError) {
                                // Red flash + subtle shake
                                final shakeOffset = sin(value * pi * 4) * (1.0 - value) * 3;
                                return Transform.translate(
                                  offset: Offset(shakeOffset, 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4757).withOpacity(glowOpacity * 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFFF4757).withOpacity(glowOpacity * 0.3),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF4757).withOpacity(glowOpacity * 0.3),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                );
                              } else if (line.isSuccess) {
                                // Green glow flash
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF41).withOpacity(glowOpacity * 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF41).withOpacity(glowOpacity * 0.2),
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                );
                              }
                              return child ?? const SizedBox.shrink();
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 1.0),
                              child: RichText(text: line.content),
                            ),
                          );
                        }

                        return lineWidget;
                      } else {
                        if (_isRunning) return const SizedBox.shrink();
                        return _buildActivePrompt();
                      }
                    },
                  ),
                ),
              ],
            ),

            // CRT Scanline overlay
            AnimatedBuilder(
              animation: _scanlineAnimation,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * _scanlineAnimation.value,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00FFD1).withOpacity(0.06),
                          const Color(0xFF00FFD1).withOpacity(0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Subtle CRT vignette
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF080D14).withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: RichText(
            text: TextSpan(
              children: [
                _span('  ┌──(', const Color(0xFF00B4D8)),
                _span('ayar㉿netforge', const Color(0xFF00FFD1)),
                _span(')-[', const Color(0xFF00B4D8)),
                _span('~', Colors.white),
                _span(']', const Color(0xFF00B4D8)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '  └─\$ ',
                style: TextStyle(
                  color: Color(0xFF00B4D8),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _targetController,
                  focusNode: _focusNode,
                  keyboardType: _isIpMode
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.url,
                  style: const TextStyle(
                    color: Color(0xFFE0E6ED),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: _isIpMode ? '192.168.1.1' : 'google.com',
                    hintStyle: TextStyle(
                      color: const Color(0xFF00FFD1).withOpacity(0.2),
                      fontFamily: 'monospace',
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    fillColor: Colors.transparent,
                  ),
                  onSubmitted: (_) => _startPing(),
                ),
              ),
              // Blinking cursor
              AnimatedBuilder(
                animation: _cursorAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _cursorAnimation.value,
                    child: Container(
                      width: 8,
                      height: 16,
                      color: const Color(0xFF00FFD1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// Very subtle matrix rain background painter
class _MatrixRainPainter extends CustomPainter {
  final double animValue;
  static final _random = Random(42);
  static final List<_MatrixDrop> _drops = List.generate(15, (_) => _MatrixDrop());

  _MatrixRainPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const chars = '01アイウエオカキクケコサシスセソタチツテト';

    for (final drop in _drops) {
      final x = drop.x * size.width;
      final baseY = ((animValue * drop.speed + drop.offset) % 1.3) * size.height;

      for (int i = 0; i < drop.length; i++) {
        final y = baseY - i * 18;
        if (y < 0 || y > size.height) continue;

        final opacity = (1.0 - i / drop.length) * 0.04;
        paint.color = const Color(0xFF00FF41).withOpacity(opacity.clamp(0.0, 0.04));

        final charIndex = (drop.charSeed + i + (animValue * 10).toInt()) % chars.length;
        final textPainter = TextPainter(
          text: TextSpan(
            text: chars[charIndex],
            style: TextStyle(
              color: paint.color,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixRainPainter oldDelegate) =>
      (oldDelegate.animValue * 100).toInt() != (animValue * 100).toInt();
}

class _MatrixDrop {
  static final _rng = Random(42);
  late double x;
  late double speed;
  late double offset;
  late int length;
  late int charSeed;

  _MatrixDrop() {
    x = _rng.nextDouble();
    speed = 0.3 + _rng.nextDouble() * 0.7;
    offset = _rng.nextDouble();
    length = 4 + _rng.nextInt(8);
    charSeed = _rng.nextInt(100);
  }
}
