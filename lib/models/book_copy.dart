enum CopyStatus { available, issued, damaged, lost }

extension CopyStatusX on CopyStatus {
  String get key {
    switch (this) {
      case CopyStatus.available:
        return 'available';
      case CopyStatus.issued:
        return 'issued';
      case CopyStatus.damaged:
        return 'damaged';
      case CopyStatus.lost:
        return 'lost';
    }
  }

  static CopyStatus fromKey(String? key) {
    switch (key) {
      case 'issued':
        return CopyStatus.issued;
      case 'damaged':
        return CopyStatus.damaged;
      case 'lost':
        return CopyStatus.lost;
      case 'available':
      default:
        return CopyStatus.available;
    }
  }
}

class BookCopy {
  BookCopy({
    required this.id,
    required this.bookId,
    required this.accessionNumber,
    required this.branch,
    required this.rack,
    this.status = CopyStatus.available,
    required this.addedOn,
    this.notes = '',
  });

  final String id;
  final String bookId;
  String accessionNumber;
  String branch;
  String rack;
  CopyStatus status;
  DateTime addedOn;
  String notes;

  factory BookCopy.fromJson(Map<String, dynamic> json) {
    return BookCopy(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      accessionNumber: json['accessionNumber'] as String,
      branch: json['branch'] as String,
      rack: json['rack'] as String,
      status: CopyStatusX.fromKey(json['status'] as String?),
      addedOn: DateTime.parse(json['addedOn'] as String),
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'accessionNumber': accessionNumber,
      'branch': branch,
      'rack': rack,
      'status': status.key,
      'addedOn': addedOn.toIso8601String(),
      'notes': notes,
    };
  }
}
