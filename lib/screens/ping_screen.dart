import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';

class TerminalLine {
  final TextSpan content;
  TerminalLine(this.content);
}

class PingScreen extends StatefulWidget {
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final TextEditingController _targetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  Ping? _ping;
  StreamSubscription? _pingSubscription;
  final List<TerminalLine> _outputLines = [];
  bool _isRunning = false;
  bool _isIpMode = true;

  @override
  void initState() {
    super.initState();
    _printMotd();
  }

  void _printMotd() {
    _outputLines.addAll([
      TerminalLine(_span('Linux noteshot-kali 6.1.0-kali3-amd64 #1 SMP PREEMPT_DYNAMIC Debian x86_64', const Color(0xFFCCCCCC))),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(_span('The programs included with the Kali GNU/Linux system are free software;', const Color(0xFFCCCCCC))),
      TerminalLine(_span('the exact distribution terms for each program are described in the', const Color(0xFFCCCCCC))),
      TerminalLine(_span('individual files in /usr/share/doc/*/copyright.', const Color(0xFFCCCCCC))),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(_span('Kali Linux comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.', const Color(0xFFCCCCCC))),
      TerminalLine(_span('', Colors.transparent)),
      TerminalLine(TextSpan(
        children: [
          _span('Welcome to ', const Color(0xFFCCCCCC)),
          _span('Ayar Suresh\'s Private Subnet', const Color(0xFFFF6B6B)),
          _span('.', const Color(0xFFCCCCCC)),
        ]
      )),
      TerminalLine(_span('Type an IP or domain to initiate packet transfer. Do not hack the Gibson.', const Color(0xFFCCCCCC))),
      TerminalLine(_span('', Colors.transparent)),
    ]);
  }

  TextSpan _span(String text, Color color) {
    return TextSpan(
      text: text,
      style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, height: 1.3),
    );
  }

  TextSpan _promptSpanWithCommand(String cmd) {
    return TextSpan(
      children: [
        _span('┌──(', const Color(0xFF00B4D8)),
        _span('root㉿kali', const Color(0xFFFF6B6B)),
        _span(')-[', const Color(0xFF00B4D8)),
        _span('~', Colors.white),
        _span(']\n└─\$ ', const Color(0xFF00B4D8)),
        _span(cmd, Colors.white),
      ],
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pingSubscription?.cancel();
    _ping?.stop();
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
      _outputLines.add(TerminalLine(_span('PING $target: 56 data bytes', Colors.white)));
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
               _outputLines.add(TerminalLine(_span('64 bytes from $target: icmp_seq=${r.seq} time=${r.time!.inMilliseconds} ms', Colors.white)));
             } else {
               _outputLines.add(TerminalLine(_span('Request timeout for icmp_seq=${r.seq}', const Color(0xFFFF6B6B))));
             }
          } else if (event.summary != null) {
             final s = event.summary!;
             _outputLines.add(TerminalLine(_span('--- $target ping statistics ---', Colors.white)));
             _outputLines.add(TerminalLine(_span('${s.transmitted} packets transmitted, ${s.received} received, ${s.transmitted - s.received} lost', Colors.white)));
          } else if (event.error != null) {
             _outputLines.add(TerminalLine(_span('ping: ${event.error}', const Color(0xFFFF6B6B))));
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
        _outputLines.add(TerminalLine(_span('^C', Colors.white)));
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
      backgroundColor: const Color(0xFF121212), // Deep grey/black for terminal
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 4,
        title: const Text(
          'root@kali:~',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          if (_isRunning)
            Tooltip(
              message: 'Send SIGINT (^C)',
              child: IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFFF6B6B)),
                onPressed: _stopPing,
              ),
            ),
          Tooltip(
            message: 'Toggle Keyboard (IP / Domain)',
            child: IconButton(
              icon: Icon(
                _isIpMode ? Icons.pin_outlined : Icons.language,
                color: const Color(0xFF00B4D8),
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
                    content: Text(_isIpMode ? 'Keyboard: IP Address' : 'Keyboard: Domain Name'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFF1E1E1E),
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
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12.0),
                itemCount: _outputLines.length + 1, // +1 for the active prompt
                itemBuilder: (context, index) {
                  if (index < _outputLines.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: RichText(text: _outputLines[index].content),
                    );
                  } else {
                    // Active input line
                    if (_isRunning) return const SizedBox.shrink();
                    return _buildActivePrompt();
                  }
                },
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
        RichText(
          text: TextSpan(
            children: [
              _span('┌──(', const Color(0xFF00B4D8)),
              _span('root㉿kali', const Color(0xFFFF6B6B)),
              _span(')-[', const Color(0xFF00B4D8)),
              _span('~', Colors.white),
              _span(']', const Color(0xFF00B4D8)),
            ]
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '└─\$ ',
              style: TextStyle(
                color: Color(0xFF00B4D8),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _targetController,
                focusNode: _focusNode,
                keyboardType: _isIpMode ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.url,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: _isIpMode ? '192.168.1.1' : 'google.com',
                  hintStyle: const TextStyle(
                    color: Colors.white24,
                    fontFamily: 'monospace',
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _startPing(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
