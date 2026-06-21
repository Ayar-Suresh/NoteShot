import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;

  const SettingsScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _showLat;
  late bool _showLon;
  late bool _showElev;
  late bool _showAccuracy;
  late bool _showNotes;
  late bool _showTime;
  late double _fontSize;
  late double _bgOpacity;
  late bool _use24Hour;
  late int _textColorIndex;

  final List<Color> _textColors = [
    const Color(0xFF00E5CC),
    const Color(0xFFFFFFFF),
    const Color(0xFFFFD700),
    const Color(0xFF00FF88),
    const Color(0xFFFF6B6B),
  ];

  final List<String> _textColorNames = [
    'Cyan',
    'White',
    'Gold',
    'Green',
    'Red',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.storageService;
    _showLat = s.showLat;
    _showLon = s.showLon;
    _showElev = s.showElev;
    _showAccuracy = s.showAccuracy;
    _showNotes = s.showNotes;
    _showTime = s.showTime;
    _fontSize = s.fontSize;
    _bgOpacity = s.bgOpacity;
    _use24Hour = s.use24Hour;
    _textColorIndex = s.textColorIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // LINE VISIBILITY
          _buildSectionHeader('LINE VISIBILITY', Icons.visibility),
          const SizedBox(height: 8),
          _buildToggleCard([
            _ToggleItem('Latitude', _showLat, (v) {
              setState(() => _showLat = v);
              widget.storageService.setShowLat(v);
            }),
            _ToggleItem('Longitude', _showLon, (v) {
              setState(() => _showLon = v);
              widget.storageService.setShowLon(v);
            }),
            _ToggleItem('Elevation', _showElev, (v) {
              setState(() => _showElev = v);
              widget.storageService.setShowElev(v);
            }),
            _ToggleItem('Accuracy', _showAccuracy, (v) {
              setState(() => _showAccuracy = v);
              widget.storageService.setShowAccuracy(v);
            }),
            _ToggleItem('Notes', _showNotes, (v) {
              setState(() => _showNotes = v);
              widget.storageService.setShowNotes(v);
            }),
            _ToggleItem('Timestamp', _showTime, (v) {
              setState(() => _showTime = v);
              widget.storageService.setShowTime(v);
            }),
          ]),
          const SizedBox(height: 20),

          // STYLE
          _buildSectionHeader('STYLE', Icons.palette),
          const SizedBox(height: 8),
          _buildStyleCard(),
          const SizedBox(height: 20),

          // TIME FORMAT
          _buildSectionHeader('TIME FORMAT', Icons.access_time),
          const SizedBox(height: 8),
          _buildTimeFormatCard(),
          const SizedBox(height: 20),

          // TEXT COLOR
          _buildSectionHeader('TEXT COLOR', Icons.color_lens),
          const SizedBox(height: 8),
          _buildColorCard(),
          const SizedBox(height: 20),

          // PREVIEW
          _buildSectionHeader('PREVIEW', Icons.preview),
          const SizedBox(height: 8),
          _buildPreviewCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E5CC), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard(List<_ToggleItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFFE0E6ED),
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: item.value,
                      onChanged: item.onChanged,
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, color: Color(0xFF2A3A4A), indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStyleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Column(
        children: [
          // Font size slider
          Row(
            children: [
              Text('Font Size',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5CC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_fontSize.round()}pt',
                  style: const TextStyle(
                    color: Color(0xFF00E5CC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 10,
            max: 24,
            divisions: 14,
            onChanged: (v) {
              setState(() => _fontSize = v);
              widget.storageService.setFontSize(v);
            },
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF2A3A4A)),
          const SizedBox(height: 8),
          // Background opacity slider
          Row(
            children: [
              Text('BG Opacity',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5CC).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(_bgOpacity * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFF00E5CC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _bgOpacity,
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: (v) {
              setState(() => _bgOpacity = v);
              widget.storageService.setBgOpacity(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFormatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '24-Hour Format',
                style: TextStyle(color: Color(0xFFE0E6ED), fontSize: 14),
              ),
              Text(
                _use24Hour ? '14:30:00' : '02:30:00 PM',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Switch(
            value: _use24Hour,
            onChanged: (v) {
              setState(() => _use24Hour = v);
              widget.storageService.setUse24Hour(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2735),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _textColors.asMap().entries.map((entry) {
          final idx = entry.key;
          final color = entry.value;
          final isSelected = idx == _textColorIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _textColorIndex = idx);
              widget.storageService.setTextColorIndex(idx);
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 40 : 34,
                  height: isSelected ? 40 : 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _textColorNames[idx],
                  style: TextStyle(
                    color: isSelected ? color : Colors.white38,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final textColor = _textColors[_textColorIndex.clamp(0, _textColors.length - 1)];
    final previewLines = <String>[];
    if (_showLat) previewLines.add('Latitude:  37.774929');
    if (_showLon) previewLines.add('Longitude: -122.419418');
    if (_showElev) previewLines.add('Elevation: 12.30±2.0 m');
    if (_showAccuracy) previewLines.add('Accuracy:  4.200 m');
    if (_showTime) {
      previewLines.add(_use24Hour ? 'Time:      18-06-2026 14:30' : 'Time:      18-06-2026 02:30 PM');
    }
    if (_showNotes) previewLines.add('Note:      Sample Location');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_bgOpacity),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...previewLines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: _fontSize,
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
                    fontSize: _fontSize * 0.75,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
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

class _ToggleItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  _ToggleItem(this.label, this.value, this.onChanged);
}
