import 'dart:async';
import 'package:flutter/material.dart';
import 'zabbix_service.dart';
import 'zabbix_storage.dart';
import 'zabbix_models.dart';
import 'widgets/zabbix_login_dialog.dart';
import 'widgets/zabbix_search_delegate.dart';

enum FilterStatus { all, problems, healthy }

class ZabbixDashboardScreen extends StatefulWidget {
  const ZabbixDashboardScreen({super.key});

  @override
  State<ZabbixDashboardScreen> createState() => _ZabbixDashboardScreenState();
}

class _ZabbixDashboardScreenState extends State<ZabbixDashboardScreen> {
  late ZabbixStorage _storage;
  late ZabbixService _service;
  
  bool _isInitialized = false;
  List<CustomGroup> _groups = [];
  List<ZabbixProblem> _currentProblems = [];
  FilterStatus _filter = FilterStatus.all;
  Timer? _pollingTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storage = await ZabbixStorage.init();
    _service = ZabbixService(_storage);
    
    setState(() {
      _groups = _storage.getGroups();
      _isInitialized = true;
    });

    if (_storage.getCookie() == null) {
      await _performAutoLogin();
    } else {
      _startPolling();
    }
  }

  Future<void> _performAutoLogin() async {
    final creds = _storage.getCredentials();
    final success = await _service.login(creds['username']!, creds['password']!);
    if (success) {
      _startPolling();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginDialog();
      });
    }
  }

  void _startPolling() {
    _fetchProblems();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _fetchProblems();
    });
  }

  Future<void> _fetchProblems() async {
    if (_isPolling) return;
    setState(() => _isPolling = true);
    
    try {
      final problems = await _service.fetchProblems();
      
      if (mounted) {
        setState(() {
          _currentProblems = problems;
          _isPolling = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('auth_failed')) {
        if (mounted) setState(() => _isPolling = false);
        _pollingTimer?.cancel();
        await _performAutoLogin();
      } else {
        if (mounted) setState(() => _isPolling = false);
      }
    }
  }

  Future<void> _showLoginDialog() async {
    final creds = _storage.getCredentials();
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ZabbixLoginDialog(
        initialUsername: creds['username'],
        initialPassword: creds['password'],
        onLogin: (u, p) async {
          final res = await _service.login(u, p);
          if (res) {
            await _storage.saveCredentials(u, p);
          }
          return res;
        },
      ),
    );

    if (success == true) {
      _startPolling();
    }
  }

  Future<void> _searchAndAddHost() async {
    final hosts = await showSearch<List<ZabbixHost>?>(
      context: context,
      delegate: ZabbixSearchDelegate(_service),
    );

    if (hosts != null && hosts.isNotEmpty && mounted) {
      _showAddHostsToGroupDialog(hosts);
    }
  }

  Future<void> _showAddHostsToGroupDialog(List<ZabbixHost> hosts) async {
    String groupName = '';
    final newGroupController = TextEditingController();
    
    final displayTitle = hosts.length == 1 ? 'Host: ${hosts.first.name}' : 'Selected ${hosts.length} Hosts';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2735),
              title: const Text('Add to Group', style: TextStyle(color: Color(0xFF00E5CC))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayTitle, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  if (_groups.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF2A3A4A),
                      value: groupName.isEmpty && _groups.isNotEmpty ? _groups.first.id : (groupName.isEmpty ? null : groupName),
                      items: _groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (val) {
                        setState(() {
                          groupName = val ?? '';
                          newGroupController.clear();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Select Existing Group'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('OR', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                  TextField(
                    controller: newGroupController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'New Group Name'),
                    onChanged: (val) {
                      setState(() {
                        if (val.isNotEmpty) groupName = '';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final isNewGroup = newGroupController.text.isNotEmpty;
                    if (isNewGroup) {
                      final newGroup = CustomGroup(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: newGroupController.text,
                        hosts: List.from(hosts),
                      );
                      _storage.addGroup(newGroup);
                    } else if (groupName.isNotEmpty) {
                      final groupIndex = _groups.indexWhere((g) => g.id == groupName);
                      if (groupIndex != -1) {
                        final g = _groups[groupIndex];
                        for (final host in hosts) {
                          if (!g.hosts.any((h) => h.id == host.id)) {
                            g.hosts.add(host);
                          }
                        }
                        _storage.saveGroups(_groups);
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );

    setState(() {
      _groups = _storage.getGroups();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ZABBIX MONITOR'),
        actions: [
          if (_isPolling)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5CC)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchProblems,
              tooltip: 'Refresh Data',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _storage.clearCookie();
              _pollingTimer?.cancel();
              if (mounted) _showLoginDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterToggle(),
          Expanded(
            child: _groups.isEmpty
                ? _buildEmptyState()
                : _buildGroupsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _searchAndAddHost,
        icon: const Icon(Icons.search),
        label: const Text('SEARCH HOSTS'),
        backgroundColor: const Color(0xFF00E5CC),
        foregroundColor: const Color(0xFF0F1923),
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2735),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A3A4A)),
        ),
        child: Row(
          children: [
            _buildTab(FilterStatus.all, 'All'),
            _buildTab(FilterStatus.problems, 'Problems'),
            _buildTab(FilterStatus.healthy, 'Healthy'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(FilterStatus status, String label) {
    final isSelected = _filter == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = status;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E5CC).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00E5CC) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart, size: 80, color: const Color(0xFF556677).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No Custom Groups Yet',
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search Zabbix to add hosts to your dashboard.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        
        // Compute host statuses
        final hostStatuses = group.hosts.map((host) {
          final problem = _currentProblems.where((p) => p.hostName.contains(host.name) || host.name.contains(p.hostName)).firstOrNull;
          return {
            'host': host,
            'isProblem': problem != null,
            'problem': problem,
          };
        }).toList();

        // Apply filters
        final filteredHosts = hostStatuses.where((h) {
          if (_filter == FilterStatus.problems) return h['isProblem'] == true;
          if (_filter == FilterStatus.healthy) return h['isProblem'] == false;
          return true;
        }).toList();

        if (filteredHosts.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: true,
            iconColor: const Color(0xFF00E5CC),
            collapsedIconColor: Colors.white54,
            title: Text(
              group.name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF00B4D8)),
            ),
            children: filteredHosts.map((item) {
              final host = item['host'] as ZabbixHost;
              final isProblem = item['isProblem'] as bool;
              final problem = item['problem'] as ZabbixProblem?;

              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isProblem ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC),
                    boxShadow: [
                      BoxShadow(
                        color: (isProblem ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC)).withValues(alpha: 0.5),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
                title: Text(host.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: isProblem 
                  ? Text(problem!.description, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12))
                  : const Text('Healthy', style: TextStyle(color: Color(0xFF00E5CC), fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white30, size: 20),
                  onPressed: () {
                    setState(() {
                      group.hosts.removeWhere((h) => h.id == host.id);
                      _storage.saveGroups(_groups);
                    });
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
