import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'zabbix_models.dart';
import 'zabbix_storage.dart';

class ZabbixService {
  static const String baseUrl = 'http://43.252.198.181/zabbix';
  final ZabbixStorage storage;

  ZabbixService(this.storage);

  Map<String, String> _getHeaders() {
    final cookie = storage.getCookie();
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      if (cookie != null) 'Cookie': cookie,
    };
  }

  Future<bool> login(String username, String password) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/index.php'));
      request.followRedirects = false;
      request.headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0',
      });
      request.bodyFields = {
        'name': username,
        'password': password,
        'autologin': '1',
        'enter': 'Sign in',
      };

      final response = await request.send();
      final rawCookie = response.headers['set-cookie'];

      if (rawCookie != null && rawCookie.contains('zbx_session=')) {
        final sessionCookie = rawCookie.split(';').firstWhere((c) => c.trim().startsWith('zbx_session=')).trim();
        await storage.saveCookie(sessionCookie);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<ZabbixHost>> searchHosts(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/zabbix.php?action=search&search=$query'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final hostSection = document.querySelector('#search_hosts');
      final List<ZabbixHost> hosts = [];

      if (hostSection != null) {
        final table = hostSection.querySelector('.list-table');
        if (table != null) {
          final rows = table.querySelectorAll('tbody tr');
          for (var row in rows) {
            final hostNameCell = row.querySelector('td');
            final hostName = hostNameCell?.text.trim() ?? '';

            String hostId = '';
            final links = row.querySelectorAll('a');
            for (var link in links) {
              final href = link.attributes['href'] ?? '';
              final match = RegExp(r'hostid[s]?.*?=([0-9]+)').firstMatch(href);
              if (match != null) {
                 hostId = match.group(1)!;
                 break;
              }
            }

            if (hostId.isNotEmpty && hostName.isNotEmpty && !hosts.any((h) => h.id == hostId)) {
              hosts.add(ZabbixHost(id: hostId, name: hostName));
            }
          }
        }
      }
      return hosts;
    } catch (e) {
      return [];
    }
  }

  Future<List<ZabbixProblem>> fetchProblems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/zabbix.php?action=problem.view.csv'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) return [];
      
      // If we get an HTML page instead of CSV, our session is invalid
      if (response.body.contains('<!DOCTYPE html>') || response.body.contains('<html')) {
        throw Exception('auth_failed');
      }

      final List<ZabbixProblem> problems = [];
      
      // Parse CSV manually since it's simple enough
      // "Severity","Time","Recovery time","Status","Host","Problem","Duration","Ack","Actions","Tags"
      final lines = const LineSplitter().convert(response.body);
      if (lines.length <= 1) return problems;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        
        // Simple CSV split (matches text within quotes)
        final matches = RegExp(r'"([^"]*)"').allMatches(line).toList();
        if (matches.length >= 6) {
          final severity = matches[0].group(1) ?? '';
          final hostName = matches[4].group(1) ?? '';
          final description = matches[5].group(1) ?? '';
          
          if (hostName.isNotEmpty) {
            problems.add(ZabbixProblem(
              hostName: hostName,
              description: description,
              severity: severity,
            ));
          }
        }
      }
      return problems;
    } catch (e) {
      return [];
    }
  }
}
