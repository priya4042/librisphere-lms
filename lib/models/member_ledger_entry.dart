enum LedgerEntryType { penalty, payment, waiver }

enum LedgerApprovalStatus { approved, pending }

extension LedgerEntryTypeX on LedgerEntryType {
  String get key {
    switch (this) {
      case LedgerEntryType.penalty:
        return 'penalty';
      case LedgerEntryType.payment:
        return 'payment';
      case LedgerEntryType.waiver:
        return 'waiver';
    }
  }

  static LedgerEntryType fromKey(String? key) {
    switch (key) {
      case 'payment':
        return LedgerEntryType.payment;
      case 'waiver':
        return LedgerEntryType.waiver;
      case 'penalty':
      default:
        return LedgerEntryType.penalty;
    }
  }
}

extension LedgerApprovalStatusX on LedgerApprovalStatus {
  String get key {
    switch (this) {
      case LedgerApprovalStatus.approved:
        return 'approved';
      case LedgerApprovalStatus.pending:
        return 'pending';
    }
  }

  static LedgerApprovalStatus fromKey(String? key) {
    switch (key) {
      case 'pending':
        return LedgerApprovalStatus.pending;
      case 'approved':
      default:
        return LedgerApprovalStatus.approved;
    }
  }
}

class MemberLedgerEntry {
  MemberLedgerEntry({
    required this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.createdOn,
    this.referenceId = '',
    this.description = '',
    this.approvalStatus = LedgerApprovalStatus.approved,
  });

  final String id;
  final String memberId;
  LedgerEntryType type;
  double amount;
  DateTime createdOn;
  String referenceId;
  String description;
  LedgerApprovalStatus approvalStatus;

  factory MemberLedgerEntry.fromJson(Map<String, dynamic> json) {
    return MemberLedgerEntry(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      type: LedgerEntryTypeX.fromKey(json['type'] as String?),
      amount: (json['amount'] as num).toDouble(),
      createdOn: DateTime.parse(json['createdOn'] as String),
      referenceId: (json['referenceId'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      approvalStatus: LedgerApprovalStatusX.fromKey(json['approvalStatus'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'memberId': memberId,
      'type': type.key,
      'amount': amount,
      'createdOn': createdOn.toIso8601String(),
      'referenceId': referenceId,
      'description': description,
      'approvalStatus': approvalStatus.key,
    };
  }
}
