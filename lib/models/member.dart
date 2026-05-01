class Member {
  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.joinedOn,
    this.membershipId = '',
    this.membershipType = 'General',
    this.department = '',
    this.address = '',
    this.status = 'Active',
    this.expiryDate,
    this.notes = '',
    this.maxBooksOverride,
  });

  final String id;
  String name;
  String email;
  String phone;
  final DateTime joinedOn;
  String membershipId;
  String membershipType;
  String department;
  String address;
  String status;
  DateTime? expiryDate;
  String notes;
  int? maxBooksOverride;

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      joinedOn: DateTime.parse(json['joinedOn'] as String),
      membershipId: (json['membershipId'] as String?) ?? '',
      membershipType: (json['membershipType'] as String?) ?? 'General',
      department: (json['department'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Active',
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      notes: (json['notes'] as String?) ?? '',
      maxBooksOverride: json['maxBooksOverride'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'joinedOn': joinedOn.toIso8601String(),
      'membershipId': membershipId,
      'membershipType': membershipType,
      'department': department,
      'address': address,
      'status': status,
      'expiryDate': expiryDate?.toIso8601String(),
      'notes': notes,
      'maxBooksOverride': maxBooksOverride,
    };
  }
}
