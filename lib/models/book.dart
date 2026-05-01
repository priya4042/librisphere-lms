class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.totalCopies,
    this.category = '',
    this.branch = '',
    this.rack = '',
    this.publisher = '',
    this.edition = '',
    this.language = 'English',
    this.publishedYear,
    this.acquisitionDate,
    this.unitPrice = 0,
    this.damagedCopies = 0,
    this.lostCopies = 0,
    this.reorderLevel = 1,
    this.tags = const <String>[],
    this.description = '',
    int? availableCopies,
  }) : availableCopies = availableCopies ?? totalCopies;

  final String id;
  String title;
  String author;
  String isbn;
  String category;
  String branch;
  String rack;
  String publisher;
  String edition;
  String language;
  int? publishedYear;
  DateTime? acquisitionDate;
  double unitPrice;
  int damagedCopies;
  int lostCopies;
  int reorderLevel;
  List<String> tags;
  String description;
  int totalCopies;
  int availableCopies;

  bool get isAvailable => availableCopies > 0;
  bool get needsReorder => availableCopies <= reorderLevel;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      isbn: json['isbn'] as String,
      category: (json['category'] as String?) ?? '',
      branch: (json['branch'] as String?) ?? '',
      rack: (json['rack'] as String?) ?? '',
      publisher: (json['publisher'] as String?) ?? '',
      edition: (json['edition'] as String?) ?? '',
      language: (json['language'] as String?) ?? 'English',
      publishedYear: json['publishedYear'] as int?,
      acquisitionDate: json['acquisitionDate'] != null
          ? DateTime.parse(json['acquisitionDate'] as String)
          : null,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      damagedCopies: (json['damagedCopies'] as int?) ?? 0,
      lostCopies: (json['lostCopies'] as int?) ?? 0,
      reorderLevel: (json['reorderLevel'] as int?) ?? 1,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
      description: (json['description'] as String?) ?? '',
      totalCopies: json['totalCopies'] as int,
      availableCopies: json['availableCopies'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'branch': branch,
      'rack': rack,
      'publisher': publisher,
      'edition': edition,
      'language': language,
      'publishedYear': publishedYear,
      'acquisitionDate': acquisitionDate?.toIso8601String(),
      'unitPrice': unitPrice,
      'damagedCopies': damagedCopies,
      'lostCopies': lostCopies,
      'reorderLevel': reorderLevel,
      'tags': tags,
      'description': description,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
    };
  }
}
