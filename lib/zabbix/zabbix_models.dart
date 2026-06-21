class ZabbixHost {
  final String id;
  final String name;

  ZabbixHost({required this.id, required this.name});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory ZabbixHost.fromJson(Map<String, dynamic> json) => ZabbixHost(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class CustomGroup {
  final String id;
  final String name;
  final List<ZabbixHost> hosts;

  CustomGroup({required this.id, required this.name, required this.hosts});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hosts': hosts.map((h) => h.toJson()).toList(),
      };

  factory CustomGroup.fromJson(Map<String, dynamic> json) => CustomGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        hosts: (json['hosts'] as List<dynamic>)
            .map((h) => ZabbixHost.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class ZabbixProblem {
  final String hostName;
  final String description;
  final String severity;

  ZabbixProblem({
    required this.hostName,
    required this.description,
    required this.severity,
  });
}
