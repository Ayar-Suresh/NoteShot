import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'zabbix_models.dart';

class ZabbixStorage {
  static const String _groupsKey = 'zabbix_custom_groups';
  static const String _cookieKey = 'zbx_sessionid_cookie';
  static const String _userKey = 'zbx_username';
  static const String _passKey = 'zbx_password';

  final SharedPreferences prefs;

  ZabbixStorage(this.prefs);

  static Future<ZabbixStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ZabbixStorage(prefs);
  }

  Future<void> saveGroups(List<CustomGroup> groups) async {
    final List<String> encoded =
        groups.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_groupsKey, encoded);
  }

  List<CustomGroup> getGroups() {
    final List<String>? encoded = prefs.getStringList(_groupsKey);
    if (encoded == null) return [];
    return encoded.map((s) => CustomGroup.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> addGroup(CustomGroup group) async {
    final groups = getGroups();
    groups.add(group);
    await saveGroups(groups);
  }

  Future<void> removeGroup(String id) async {
    final groups = getGroups();
    groups.removeWhere((g) => g.id == id);
    await saveGroups(groups);
  }

  Future<void> saveCookie(String cookie) async {
    await prefs.setString(_cookieKey, cookie);
  }

  String? getCookie() {
    return prefs.getString(_cookieKey);
  }

  Future<void> clearCookie() async {
    await prefs.remove(_cookieKey);
  }

  Future<void> saveCredentials(String username, String password) async {
    await prefs.setString(_userKey, username);
    await prefs.setString(_passKey, password);
  }

  Map<String, String> getCredentials() {
    return {
      'username': prefs.getString(_userKey) ?? 'sipl-team',
      'password': prefs.getString(_passKey) ?? 'sipl1234',
    };
  }
}
