class Acquisition {
  Acquisition({
    required this.id,
    required this.bookId,
    required this.vendor,
    required this.branch,
    required this.quantity,
    required this.unitCost,
    required this.acquiredOn,
    this.invoiceNumber = '',
    this.notes = '',
  });

  final String id;
  final String bookId;
  String vendor;
  String branch;
  int quantity;
  double unitCost;
  DateTime acquiredOn;
  String invoiceNumber;
  String notes;

  double get totalCost => quantity * unitCost;

  factory Acquisition.fromJson(Map<String, dynamic> json) {
    return Acquisition(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      vendor: json['vendor'] as String,
      branch: json['branch'] as String,
      quantity: json['quantity'] as int,
      unitCost: (json['unitCost'] as num).toDouble(),
      acquiredOn: DateTime.parse(json['acquiredOn'] as String),
      invoiceNumber: (json['invoiceNumber'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bookId': bookId,
      'vendor': vendor,
      'branch': branch,
      'quantity': quantity,
      'unitCost': unitCost,
      'acquiredOn': acquiredOn.toIso8601String(),
      'invoiceNumber': invoiceNumber,
      'notes': notes,
    };
  }
}
