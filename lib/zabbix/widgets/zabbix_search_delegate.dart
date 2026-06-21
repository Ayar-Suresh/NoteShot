import 'package:flutter/material.dart';
import '../zabbix_service.dart';
import '../zabbix_models.dart';

class ZabbixSearchDelegate extends SearchDelegate<List<ZabbixHost>?> {
  final ZabbixService service;

  ZabbixSearchDelegate(this.service);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2735),
        iconTheme: IconThemeData(color: Color(0xFF00E5CC)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Color(0xFF556677)),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<ZabbixHost>>(
      future: service.searchHosts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5CC)));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No hosts found', style: TextStyle(color: Colors.white54)),
          );
        }

        final hosts = snapshot.data!;
        return ListView.separated(
          itemCount: hosts.length + (hosts.length > 1 ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF2A3A4A), height: 1),
          itemBuilder: (context, index) {
            if (hosts.length > 1 && index == 0) {
              return ListTile(
                leading: const Icon(Icons.library_add, color: Color(0xFF00E5CC)),
                title: Text('Add All ${hosts.length} Hosts', style: const TextStyle(color: Color(0xFF00E5CC), fontWeight: FontWeight.bold)),
                onTap: () {
                  close(context, hosts);
                },
              );
            }
            final host = hosts[hosts.length > 1 ? index - 1 : index];
            return ListTile(
              leading: const Icon(Icons.computer, color: Color(0xFF00B4D8)),
              title: Text(host.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('ID: ${host.id}', style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5CC)),
              onTap: () {
                close(context, [host]);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text(
        'Type to search Zabbix...',
        style: TextStyle(color: Color(0xFF556677)),
      ),
    );
  }
}
