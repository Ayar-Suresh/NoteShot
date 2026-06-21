import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final baseUrl = 'http://43.252.198.181/zabbix';
  
  // 1. Login
  final loginRes = await http.post(
    Uri.parse('$baseUrl/index.php'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': 'Mozilla/5.0',
    },
    body: {
      'name': 'sipl-team',
      'password': 'sipl1234',
      'autologin': '1',
      'enter': 'Sign in',
    },
  );

  final rawCookie = loginRes.headers['set-cookie'];
  String cookie = '';
  if (rawCookie != null && rawCookie.contains('zbx_session=')) {
    cookie = rawCookie.split(';').firstWhere((c) => c.trim().startsWith('zbx_session=')).trim();
  }

  if (cookie.isEmpty) {
    print('Failed to get cookie.');
    return;
  }
  
  print('Cookie: \$cookie');

  // 2. Fetch Search page for 'CHARANKA'
  final searchRes = await http.get(
    Uri.parse('$baseUrl/zabbix.php?action=search&search=CHARANKA'),
    headers: {
      'Cookie': cookie,
      'User-Agent': 'Mozilla/5.0',
    },
  );
  File('search_dump.html').writeAsStringSync(searchRes.body);

  // 3. Fetch Dashboard page (Global view)
  final dashRes = await http.get(
    Uri.parse('$baseUrl/zabbix.php?action=dashboard.view'),
    headers: {
      'Cookie': cookie,
      'User-Agent': 'Mozilla/5.0',
    },
  );
  File('dash_dump.html').writeAsStringSync(dashRes.body);

  // 4. Fetch Problem View
  final probRes = await http.get(
    Uri.parse('$baseUrl/zabbix.php?action=problem.view'),
    headers: {
      'Cookie': cookie,
      'User-Agent': 'Mozilla/5.0',
    },
  );
  File('prob_dump.html').writeAsStringSync(probRes.body);

  print('Dumped HTML to files.');
}
