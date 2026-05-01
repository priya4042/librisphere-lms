class BorrowRecord {
  BorrowRecord({
    required this.id,
    required this.bookId,
    required this.memberId,
    this.copyId,
    required this.issuedOn,
    required this.dueOn,
    this.returnedOn,
    this.finePaid = 0,
    this.renewCount = 0,
  });

  final String id;
  final String bookId;
  final String memberId;
  final String? copyId;
  final DateTime issuedOn;
  final DateTime dueOn;
  DateTime? returnedOn;
  double finePaid;
  int renewCount;

  bool get isReturned => returnedOn != null;

  bool get isOverdue => !isReturned && DateTime.now().isAfter(dueOn);

  factory BorrowRecord.fromJson(Map<String, dynamic> json) {
    return BorrowRecord(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      memberId: json['memberId'] as String,
      copyId: json['copyId'] as String?,
      issuedOn: DateTime.parse(json['issuedOn'] as String),
      dueOn: DateTime.parse(json['dueOn'] as String),
      returnedOn: json['returnedOn'] != null
          ? DateTime.parse(json['returnedOn'] as String)
          : null,
      finePaid: (json['finePaid'] as num?)?.toDouble() ?? 0,
      renewCount: (json['renewCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'memberId': memberId,
      'copyId': copyId,
      'issuedOn': issuedOn.toIso8601String(),
      'dueOn': dueOn.toIso8601String(),
      'returnedOn': returnedOn?.toIso8601String(),
      'finePaid': finePaid,
      'renewCount': renewCount,
    };
  }
}
