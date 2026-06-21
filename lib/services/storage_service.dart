import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyNoteText = 'note_text';
  static const _keyShowLat = 'show_lat';
  static const _keyShowLon = 'show_lon';
  static const _keyShowElev = 'show_elev';
  static const _keyShowAccuracy = 'show_accuracy';
  static const _keyShowNotes = 'show_notes';
  static const _keyShowTime = 'show_time';
  static const _keyFontSize = 'font_size';
  static const _keyBgOpacity = 'bg_opacity';
  static const _keyUse24Hour = 'use_24_hour';
  static const _keyTextColorIndex = 'text_color_index';
  static const _keyCustomUrls = 'custom_urls';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Note text
  String get noteText => _prefs.getString(_keyNoteText) ?? '';
  Future<void> setNoteText(String value) =>
      _prefs.setString(_keyNoteText, value);

  // Line visibility toggles
  bool get showLat => _prefs.getBool(_keyShowLat) ?? true;
  Future<void> setShowLat(bool value) => _prefs.setBool(_keyShowLat, value);

  bool get showLon => _prefs.getBool(_keyShowLon) ?? true;
  Future<void> setShowLon(bool value) => _prefs.setBool(_keyShowLon, value);

  bool get showElev => _prefs.getBool(_keyShowElev) ?? true;
  Future<void> setShowElev(bool value) => _prefs.setBool(_keyShowElev, value);

  bool get showAccuracy => _prefs.getBool(_keyShowAccuracy) ?? true;
  Future<void> setShowAccuracy(bool value) =>
      _prefs.setBool(_keyShowAccuracy, value);

  bool get showNotes => _prefs.getBool(_keyShowNotes) ?? true;
  Future<void> setShowNotes(bool value) => _prefs.setBool(_keyShowNotes, value);

  bool get showTime => _prefs.getBool(_keyShowTime) ?? true;
  Future<void> setShowTime(bool value) => _prefs.setBool(_keyShowTime, value);

  // Style settings
  double get fontSize => _prefs.getDouble(_keyFontSize) ?? 13.0;
  Future<void> setFontSize(double value) =>
      _prefs.setDouble(_keyFontSize, value);

  double get bgOpacity => _prefs.getDouble(_keyBgOpacity) ?? 0.75;
  Future<void> setBgOpacity(double value) =>
      _prefs.setDouble(_keyBgOpacity, value);

  // Time format
  bool get use24Hour => _prefs.getBool(_keyUse24Hour) ?? false;
  Future<void> setUse24Hour(bool value) =>
      _prefs.setBool(_keyUse24Hour, value);

  // Text color
  int get textColorIndex => _prefs.getInt(_keyTextColorIndex) ?? 0;
  Future<void> setTextColorIndex(int value) =>
      _prefs.setInt(_keyTextColorIndex, value);

  // Custom URLs for speed test
  List<String> get customUrls => _prefs.getStringList(_keyCustomUrls) ?? [];
  Future<void> addCustomUrl(String url) async {
    final urls = customUrls;
    if (!urls.contains(url)) {
      urls.add(url);
      await _prefs.setStringList(_keyCustomUrls, urls);
    }
  }

  /// Build a consolidated map for overlay payload transmission
  Map<String, dynamic> toOverlayPayload() => {
        'noteText': noteText,
        'showLat': showLat,
        'showLon': showLon,
        'showElev': showElev,
        'showAccuracy': showAccuracy,
        'showNotes': showNotes,
        'showTime': showTime,
        'fontSize': fontSize,
        'bgOpacity': bgOpacity,
        'use24Hour': use24Hour,
        'textColorIndex': textColorIndex,
      };
}
