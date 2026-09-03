
class AuditLog {
  final String id;
  final DateTime timestamp;
  final String category;
  final String action;
  final String? actorId;
  final String? machineId;
  final Map<String, dynamic>? details;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.action,
    this.actorId,
    this.machineId,
    this.details,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
      category: json['category'],
      action: json['action'],
      actorId: json['actor_id'],
      machineId: json['machine_id'],
      details: json['details'],
    );
  }
}
