class AuditLog {
  AuditLog({
    required this.id,
    required this.timestamp,
    required this.role,
    required this.action,
    required this.details,
  });

  final String id;
  final DateTime timestamp;
  final String role;
  final String action;
  final String details;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      role: json['role'] as String,
      action: json['action'] as String,
      details: json['details'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'role': role,
      'action': action,
      'details': details,
    };
  }
}
