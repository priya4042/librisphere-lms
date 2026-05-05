import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/member.dart';
import '../models/user_role.dart';
import '../models/audit_log.dart';
import '../models/acquisition.dart';
import '../models/vendor.dart';
import '../models/book_copy.dart';
import '../models/member_ledger_entry.dart';

class LibraryProvider extends ChangeNotifier {
  static const String _storageKey = 'lms_state_v1';

  final List<Book> _books = <Book>[];
  final List<Member> _members = <Member>[];
  final List<BorrowRecord> _records = <BorrowRecord>[];
  final List<AuditLog> _auditLogs = <AuditLog>[];
  final List<Acquisition> _acquisitions = <Acquisition>[];
  final List<Vendor> _vendors = <Vendor>[];
  final List<BookCopy> _bookCopies = <BookCopy>[];
  final List<MemberLedgerEntry> _ledgerEntries = <MemberLedgerEntry>[];
  final Uuid _uuid = const Uuid();
  bool _isReady = false;
  UserRole _currentRole = UserRole.admin;
  String _adminPin = '1234';

  int _defaultBorrowDays = 14;
  double _finePerDay = 5;
  int _maxBooksPerMember = 3;
  int _maxRenewals = 2;
  bool _blockIssueOnOutstandingBalance = false;
  double _maxOutstandingBalanceForIssue = 0;
  final Map<String, List<String>> _waitlistByBook = <String, List<String>>{};

  LibraryProvider() {
    unawaited(_initialize());
  }

  bool get isReady => _isReady;
  int get defaultBorrowDays => _defaultBorrowDays;
  double get finePerDay => _finePerDay;
  int get maxBooksPerMember => _maxBooksPerMember;
  int get maxRenewals => _maxRenewals;
  bool get blockIssueOnOutstandingBalance => _blockIssueOnOutstandingBalance;
  double get maxOutstandingBalanceForIssue => _maxOutstandingBalanceForIssue;
  UserRole get currentRole => _currentRole;
  bool get canManageBooks => _currentRole != UserRole.guest;
  bool get canManageMembers => _currentRole != UserRole.guest;
  bool get canManageCirculation => _currentRole != UserRole.guest;
  bool get canAccessSettings => _currentRole == UserRole.admin;
  bool get canViewAudit => _currentRole == UserRole.admin;

  UnmodifiableListView<Book> get books => UnmodifiableListView<Book>(_books);
  UnmodifiableListView<Member> get members => UnmodifiableListView<Member>(_members);
  UnmodifiableListView<BorrowRecord> get records =>
      UnmodifiableListView<BorrowRecord>(_records);
  UnmodifiableListView<AuditLog> get auditLogs => UnmodifiableListView<AuditLog>(_auditLogs);
  UnmodifiableListView<Acquisition> get acquisitions =>
      UnmodifiableListView<Acquisition>(_acquisitions);
  UnmodifiableListView<Vendor> get vendors => UnmodifiableListView<Vendor>(_vendors);
  UnmodifiableListView<BookCopy> get bookCopies => UnmodifiableListView<BookCopy>(_bookCopies);
  UnmodifiableListView<MemberLedgerEntry> get ledgerEntries =>
      UnmodifiableListView<MemberLedgerEntry>(_ledgerEntries);

  List<BorrowRecord> get activeBorrowRecords =>
      _records.where((BorrowRecord r) => !r.isReturned).toList();

  List<BorrowRecord> get completedBorrowRecords =>
      _records.where((BorrowRecord r) => r.isReturned).toList();

  int get totalTitles => _books.length;
  int get totalMembers => _members.length;
  int get borrowedCount => activeBorrowRecords.length;
  int get overdueCount => activeBorrowRecords.where((BorrowRecord r) => r.isOverdue).length;
  int get availableCopiesCount =>
      _books.fold<int>(0, (int sum, Book b) => sum + b.availableCopies);
  double get totalInventoryValue => _books.fold<double>(
        0,
        (double sum, Book b) => sum + (b.unitPrice * b.totalCopies),
      );
  double get totalFineCollected =>
      _records.fold<double>(0, (double sum, BorrowRecord r) => sum + r.finePaid);
  double get totalFineOutstanding => activeBorrowRecords.fold<double>(
        0,
        (double sum, BorrowRecord r) => sum + pendingFineForRecord(r),
      );

  int get totalReservations =>
      _waitlistByBook.values.fold<int>(0, (int sum, List<String> q) => sum + q.length);
  int get dueTodayCount => activeBorrowRecords.where((BorrowRecord r) {
        final DateTime now = DateTime.now();
        return r.dueOn.year == now.year && r.dueOn.month == now.month && r.dueOn.day == now.day;
      }).length;
  int get dueSoonCount => dueSoonRecords().length;
  int get branchCount =>
      _books.map((Book b) => b.branch.trim()).where((String s) => s.isNotEmpty).toSet().length;
  int get categoryCount => _books
      .map((Book b) => b.category.trim())
      .where((String s) => s.isNotEmpty)
      .toSet()
      .length;
  int get activeMembershipCount => _members.where((Member m) => m.status == 'Active').length;
  int get expiredMembershipCount => _members.where((Member m) {
        if (m.expiryDate == null) {
          return false;
        }
        return m.expiryDate!.isBefore(DateTime.now());
      }).length;
  int get damagedCopiesCount =>
      _books.fold<int>(0, (int sum, Book b) => sum + b.damagedCopies);
  int get lostCopiesCount => _books.fold<int>(0, (int sum, Book b) => sum + b.lostCopies);
  double get acquisitionSpend =>
      _acquisitions.fold<double>(0, (double sum, Acquisition a) => sum + a.totalCost);
  int get vendorCount => _vendors.length;
  int get totalCopiesTracked => _bookCopies.length;
  int get issuedCopiesTracked =>
      _bookCopies.where((BookCopy copy) => copy.status == CopyStatus.issued).length;
  int get pendingPenaltyApprovals => _ledgerEntries
      .where(
      (MemberLedgerEntry e) =>
        e.type == LedgerEntryType.penalty &&
        e.approvalStatus == LedgerApprovalStatus.pending,
      )
      .length;

  Future<void> _initialize() async {
    await _loadState();
    if (_books.isEmpty && _members.isEmpty && _records.isEmpty) {
      _seedData();
      await _saveState();
    }
    _isReady = true;
    notifyListeners();
  }

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);
      _applyStateMap(json);
    } catch (_) {
      _books.clear();
      _members.clear();
      _records.clear();
      _waitlistByBook.clear();
    }
  }

  Future<void> _saveState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> json = _toStateMap();
    await prefs.setString(_storageKey, jsonEncode(json));
  }

  Map<String, dynamic> _toStateMap() {
    return <String, dynamic>{
      'books': _books.map((Book b) => b.toJson()).toList(),
      'members': _members.map((Member m) => m.toJson()).toList(),
      'records': _records.map((BorrowRecord r) => r.toJson()).toList(),
      'defaultBorrowDays': _defaultBorrowDays,
      'finePerDay': _finePerDay,
      'maxBooksPerMember': _maxBooksPerMember,
      'maxRenewals': _maxRenewals,
      'blockIssueOnOutstandingBalance': _blockIssueOnOutstandingBalance,
      'maxOutstandingBalanceForIssue': _maxOutstandingBalanceForIssue,
      'waitlistByBook': _waitlistByBook,
      'currentRole': _currentRole.key,
      'adminPin': _adminPin,
      'auditLogs': _auditLogs.map((AuditLog e) => e.toJson()).toList(),
      'acquisitions': _acquisitions.map((Acquisition e) => e.toJson()).toList(),
      'vendors': _vendors.map((Vendor e) => e.toJson()).toList(),
      'bookCopies': _bookCopies.map((BookCopy e) => e.toJson()).toList(),
      'ledgerEntries': _ledgerEntries.map((MemberLedgerEntry e) => e.toJson()).toList(),
    };
  }

  void _applyStateMap(Map<String, dynamic> json) {
    final List<dynamic> booksJson = (json['books'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> membersJson = (json['members'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> recordsJson = (json['records'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> acquisitionsJson =
      (json['acquisitions'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> vendorsJson = (json['vendors'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> copiesJson = (json['bookCopies'] as List<dynamic>? ?? <dynamic>[]);
    final List<dynamic> ledgerJson =
      (json['ledgerEntries'] as List<dynamic>? ?? <dynamic>[]);

    _books
      ..clear()
      ..addAll(
        booksJson.map((dynamic e) => Book.fromJson(Map<String, dynamic>.from(e as Map))),
      );

    _members
      ..clear()
      ..addAll(
        membersJson.map(
          (dynamic e) => Member.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _records
      ..clear()
      ..addAll(
        recordsJson.map(
          (dynamic e) => BorrowRecord.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _acquisitions
      ..clear()
      ..addAll(
        acquisitionsJson.map(
          (dynamic e) => Acquisition.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _vendors
      ..clear()
      ..addAll(
        vendorsJson.map(
          (dynamic e) => Vendor.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _bookCopies
      ..clear()
      ..addAll(
        copiesJson.map(
          (dynamic e) => BookCopy.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _ledgerEntries
      ..clear()
      ..addAll(
        ledgerJson.map(
          (dynamic e) => MemberLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    _defaultBorrowDays = (json['defaultBorrowDays'] as int?) ?? 14;
    _finePerDay = (json['finePerDay'] as num?)?.toDouble() ?? 5;
    _maxBooksPerMember = (json['maxBooksPerMember'] as int?) ?? 3;
    _maxRenewals = (json['maxRenewals'] as int?) ?? 2;
    _blockIssueOnOutstandingBalance =
      (json['blockIssueOnOutstandingBalance'] as bool?) ?? false;
    _maxOutstandingBalanceForIssue =
      (json['maxOutstandingBalanceForIssue'] as num?)?.toDouble() ?? 0;
    _currentRole = UserRoleX.fromKey(json['currentRole'] as String?);
    _adminPin = (json['adminPin'] as String?) ?? '1234';

    _waitlistByBook.clear();
    final Map<String, dynamic> waitlistJson =
        Map<String, dynamic>.from(json['waitlistByBook'] as Map? ?? <String, dynamic>{});
    for (final MapEntry<String, dynamic> entry in waitlistJson.entries) {
      _waitlistByBook[entry.key] =
          (entry.value as List<dynamic>).map((dynamic e) => e.toString()).toList();
    }

    _auditLogs
      ..clear()
      ..addAll(
        (json['auditLogs'] as List<dynamic>? ?? <dynamic>[]).map(
          (dynamic e) => AuditLog.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  }

  bool verifyAdminPin(String pin) {
    return pin.trim() == _adminPin;
  }

  String switchRoleSecure(UserRole role, String pin) {
    if (!verifyAdminPin(pin)) {
      return 'Invalid admin PIN.';
    }
    if (_currentRole == role) {
      return 'Already in ${role.label} role.';
    }
    _currentRole = role;
    _log('Role Changed', 'Switched to ${role.label}');
    _persistAndNotify();
    return 'Role switched to ${role.label}.';
  }

  String updateAdminPin({required String oldPin, required String newPin}) {
    if (!canAccessSettings) {
      return 'Permission denied for current role.';
    }
    if (!verifyAdminPin(oldPin)) {
      return 'Current PIN is incorrect.';
    }
    final String trimmed = newPin.trim();
    if (trimmed.length < 4 || int.tryParse(trimmed) == null) {
      return 'New PIN must be at least 4 numeric digits.';
    }
    _adminPin = trimmed;
    _log('Admin PIN Updated', 'PIN changed successfully');
    _persistAndNotify();
    return 'Admin PIN updated successfully.';
  }

  void _log(String action, String details) {
    _auditLogs.insert(
      0,
      AuditLog(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        role: _currentRole.label,
        action: action,
        details: details,
      ),
    );
    if (_auditLogs.length > 300) {
      _auditLogs.removeRange(300, _auditLogs.length);
    }
  }

  void _persistAndNotify() {
    notifyListeners();
    unawaited(_saveState());
  }

  Book? getBookById(String id) {
    try {
      return _books.firstWhere((Book b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Member? getMemberById(String id) {
    try {
      return _members.firstWhere((Member m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BookCopy> copiesForBook(String bookId) {
    return _bookCopies.where((BookCopy copy) => copy.bookId == bookId).toList();
  }

  List<BookCopy> searchCopies(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _bookCopies.toList();
    }
    return _bookCopies
        .where(
          (BookCopy copy) =>
              copy.accessionNumber.toLowerCase().contains(q) ||
              copy.branch.toLowerCase().contains(q) ||
              copy.rack.toLowerCase().contains(q) ||
              copy.status.key.contains(q),
        )
        .toList();
  }

  List<Vendor> searchVendors(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _vendors.toList();
    }
    return _vendors
        .where(
          (Vendor vendor) =>
              vendor.name.toLowerCase().contains(q) ||
              vendor.contactPerson.toLowerCase().contains(q) ||
              vendor.phone.toLowerCase().contains(q) ||
              vendor.email.toLowerCase().contains(q),
        )
        .toList();
  }

  List<MemberLedgerEntry> ledgerForMember(String memberId) {
    return _ledgerEntries.where((MemberLedgerEntry e) => e.memberId == memberId).toList();
  }

  List<BorrowRecord> dueSoonRecords({int withinDays = 3}) {
    final DateTime now = DateTime.now();
    final DateTime end = now.add(Duration(days: withinDays));
    return activeBorrowRecords.where((BorrowRecord record) {
      return !record.dueOn.isBefore(now) && !record.dueOn.isAfter(end);
    }).toList();
  }

  double memberBalance(String memberId) {
    final List<MemberLedgerEntry> entries = ledgerForMember(memberId)
        .where((MemberLedgerEntry e) => e.approvalStatus == LedgerApprovalStatus.approved)
        .toList();
    double balance = 0;
    for (final MemberLedgerEntry entry in entries) {
      if (entry.type == LedgerEntryType.penalty) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  String _nextAccession(String bookId) {
    final int count = _bookCopies.where((BookCopy copy) => copy.bookId == bookId).length + 1;
    return '${bookId.substring(0, 8).toUpperCase()}-${count.toString().padLeft(5, '0')}';
  }

  void _createCopiesForBook(Book book, int quantity) {
    for (int i = 0; i < quantity; i++) {
      _bookCopies.add(
        BookCopy(
          id: _uuid.v4(),
          bookId: book.id,
          accessionNumber: _nextAccession(book.id),
          branch: book.branch,
          rack: book.rack,
          status: CopyStatus.available,
          addedOn: DateTime.now(),
        ),
      );
    }
  }

  int activeIssuedCountForMember(String memberId) {
    return activeBorrowRecords.where((BorrowRecord r) => r.memberId == memberId).length;
  }

  int totalBorrowCountForMember(String memberId) {
    return _records.where((BorrowRecord r) => r.memberId == memberId).length;
  }

  int totalBorrowCountForBook(String bookId) {
    return _records.where((BorrowRecord r) => r.bookId == bookId).length;
  }

  List<Member> waitlistMembersForBook(String bookId) {
    final List<String> queue = _waitlistByBook[bookId] ?? <String>[];
    return queue
        .map((String memberId) => getMemberById(memberId))
        .whereType<Member>()
        .toList();
  }

  int waitlistCountForBook(String bookId) {
    return _waitlistByBook[bookId]?.length ?? 0;
  }

  void addBook({
    required String title,
    required String author,
    required String isbn,
    required int totalCopies,
    String category = '',
    String branch = '',
    String rack = '',
    String publisher = '',
    String edition = '',
    String language = 'English',
    int? publishedYear,
    DateTime? acquisitionDate,
    double unitPrice = 0,
    int reorderLevel = 1,
    List<String> tags = const <String>[],
    String description = '',
  }) {
    if (!canManageBooks) {
      return;
    }
    final Book book = Book(
        id: _uuid.v4(),
        title: title.trim(),
        author: author.trim(),
        isbn: isbn.trim(),
        category: category.trim(),
        branch: branch.trim(),
        rack: rack.trim(),
        publisher: publisher.trim(),
        edition: edition.trim(),
        language: language.trim().isEmpty ? 'English' : language.trim(),
        publishedYear: publishedYear,
        acquisitionDate: acquisitionDate,
        unitPrice: unitPrice,
        reorderLevel: reorderLevel <= 0 ? 1 : reorderLevel,
        tags: tags,
        description: description,
        totalCopies: totalCopies,
      );
    _books.add(book);
    _createCopiesForBook(book, totalCopies);
    _log('Book Added', '$title by $author');
    _persistAndNotify();
  }

  void updateBook(
    String id, {
    required String title,
    required String author,
    required String isbn,
    required int totalCopies,
    String category = '',
    String branch = '',
    String rack = '',
    String publisher = '',
    String edition = '',
    String language = 'English',
    int? publishedYear,
    DateTime? acquisitionDate,
    double unitPrice = 0,
    int reorderLevel = 1,
    List<String> tags = const <String>[],
    String description = '',
  }) {
    if (!canManageBooks) {
      return;
    }
    final Book? book = getBookById(id);
    if (book == null) {
      return;
    }

    final int borrowedCopies =
        book.totalCopies - book.availableCopies - book.damagedCopies - book.lostCopies;
    if (totalCopies < borrowedCopies + book.damagedCopies + book.lostCopies) {
      return;
    }

    book
      ..title = title.trim()
      ..author = author.trim()
      ..isbn = isbn.trim()
      ..category = category.trim()
      ..branch = branch.trim()
      ..rack = rack.trim()
      ..publisher = publisher.trim()
      ..edition = edition.trim()
      ..language = language.trim().isEmpty ? 'English' : language.trim()
      ..publishedYear = publishedYear
      ..acquisitionDate = acquisitionDate
      ..unitPrice = unitPrice
      ..reorderLevel = reorderLevel <= 0 ? 1 : reorderLevel
      ..tags = tags.map((String t) => t.trim()).where((String t) => t.isNotEmpty).toList()
      ..description = description.trim()
      ..totalCopies = totalCopies
      ..availableCopies = totalCopies - borrowedCopies - book.damagedCopies - book.lostCopies;

    _log('Book Updated', '${book.title} (${book.isbn})');
    _persistAndNotify();
  }

  bool deleteBook(String id) {
    if (!canManageBooks) {
      return false;
    }
    final Book? book = getBookById(id);
    final bool hasActiveIssues =
        activeBorrowRecords.any((BorrowRecord r) => r.bookId == id);
    if (hasActiveIssues) {
      return false;
    }

    _books.removeWhere((Book b) => b.id == id);
    _records.removeWhere((BorrowRecord r) => r.bookId == id);
    _bookCopies.removeWhere((BookCopy copy) => copy.bookId == id);
    _log('Book Deleted', book?.title ?? id);
    _persistAndNotify();
    return true;
  }

  void addAcquisition({
    required String bookId,
    required String vendor,
    required String branch,
    required int quantity,
    required double unitCost,
    String invoiceNumber = '',
    String notes = '',
  }) {
    if (!canManageBooks || quantity <= 0 || unitCost < 0) {
      return;
    }

    final Book? book = getBookById(bookId);
    if (book == null) {
      return;
    }

    book
      ..totalCopies += quantity
      ..availableCopies += quantity;

    _createCopiesForBook(book, quantity);

    if (branch.trim().isNotEmpty) {
      book.branch = branch.trim();
    }

    final bool vendorExists =
        _vendors.any((Vendor v) => v.name.toLowerCase() == vendor.trim().toLowerCase());
    if (!vendorExists && vendor.trim().isNotEmpty) {
      _vendors.add(Vendor(id: _uuid.v4(), name: vendor.trim()));
    }

    _acquisitions.insert(
      0,
      Acquisition(
        id: _uuid.v4(),
        bookId: bookId,
        vendor: vendor.trim(),
        branch: branch.trim(),
        quantity: quantity,
        unitCost: unitCost,
        acquiredOn: DateTime.now(),
        invoiceNumber: invoiceNumber.trim(),
        notes: notes.trim(),
      ),
    );

    if (unitCost > 0) {
      book.unitPrice = unitCost;
    }

    _log('Acquisition Added', 'Book=$bookId Qty=$quantity Vendor=$vendor');
    _persistAndNotify();
  }

  bool markBookDamaged(String bookId, {int quantity = 1}) {
    if (!canManageBooks || quantity <= 0) {
      return false;
    }
    final Book? book = getBookById(bookId);
    if (book == null || book.availableCopies < quantity) {
      return false;
    }

    int marked = 0;
    for (final BookCopy copy in _bookCopies.where((BookCopy c) => c.bookId == bookId)) {
      if (copy.status == CopyStatus.available) {
        copy.status = CopyStatus.damaged;
        marked += 1;
        if (marked == quantity) {
          break;
        }
      }
    }
    if (marked < quantity) {
      return false;
    }
    book
      ..availableCopies -= quantity
      ..damagedCopies += quantity;
    _log('Book Damaged', 'Book=$bookId Qty=$quantity');
    _persistAndNotify();
    return true;
  }

  bool restoreDamagedBook(String bookId, {int quantity = 1}) {
    if (!canManageBooks || quantity <= 0) {
      return false;
    }
    final Book? book = getBookById(bookId);
    if (book == null || book.damagedCopies < quantity) {
      return false;
    }

    int restored = 0;
    for (final BookCopy copy in _bookCopies.where((BookCopy c) => c.bookId == bookId)) {
      if (copy.status == CopyStatus.damaged) {
        copy.status = CopyStatus.available;
        restored += 1;
        if (restored == quantity) {
          break;
        }
      }
    }
    if (restored < quantity) {
      return false;
    }
    book
      ..damagedCopies -= quantity
      ..availableCopies += quantity;
    _log('Damaged Book Restored', 'Book=$bookId Qty=$quantity');
    _persistAndNotify();
    return true;
  }

  bool markBookLost(String bookId, {int quantity = 1}) {
    if (!canManageBooks || quantity <= 0) {
      return false;
    }
    final Book? book = getBookById(bookId);
    if (book == null || book.availableCopies < quantity) {
      return false;
    }

    int marked = 0;
    for (final BookCopy copy in _bookCopies.where((BookCopy c) => c.bookId == bookId)) {
      if (copy.status == CopyStatus.available) {
        copy.status = CopyStatus.lost;
        marked += 1;
        if (marked == quantity) {
          break;
        }
      }
    }
    if (marked < quantity) {
      return false;
    }
    book
      ..availableCopies -= quantity
      ..lostCopies += quantity;
    _log('Book Lost', 'Book=$bookId Qty=$quantity');
    _persistAndNotify();
    return true;
  }

  void addVendor({
    required String name,
    String contactPerson = '',
    String email = '',
    String phone = '',
    String address = '',
    String gstNumber = '',
    String paymentTerms = '',
    int rating = 0,
  }) {
    if (!canManageBooks || name.trim().isEmpty) {
      return;
    }
    _vendors.add(
      Vendor(
        id: _uuid.v4(),
        name: name.trim(),
        contactPerson: contactPerson.trim(),
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        gstNumber: gstNumber.trim(),
        paymentTerms: paymentTerms.trim(),
        rating: rating,
      ),
    );
    _log('Vendor Added', name);
    _persistAndNotify();
  }

  void updateVendor(
    String id, {
    required String name,
    String contactPerson = '',
    String email = '',
    String phone = '',
    String address = '',
    String gstNumber = '',
    String paymentTerms = '',
    int rating = 0,
  }) {
    Vendor? vendor;
    for (final Vendor v in _vendors) {
      if (v.id == id) {
        vendor = v;
        break;
      }
    }
    if (vendor == null) {
      return;
    }
    vendor
      ..name = name.trim()
      ..contactPerson = contactPerson.trim()
      ..email = email.trim()
      ..phone = phone.trim()
      ..address = address.trim()
      ..gstNumber = gstNumber.trim()
      ..paymentTerms = paymentTerms.trim()
      ..rating = rating;
    _log('Vendor Updated', vendor.name);
    _persistAndNotify();
  }

  bool deleteVendor(String id) {
    Vendor? vendor;
    for (final Vendor v in _vendors) {
      if (v.id == id) {
        vendor = v;
        break;
      }
    }
    if (vendor == null) {
      return false;
    }
    final bool used =
        _acquisitions.any((Acquisition acquisition) => acquisition.vendor == vendor!.name);
    if (used) {
      return false;
    }
    _vendors.removeWhere((Vendor v) => v.id == id);
    _log('Vendor Deleted', vendor.name);
    _persistAndNotify();
    return true;
  }

  bool transferCopy(
    String copyId, {
    required String branch,
    required String rack,
  }) {
    BookCopy? copy;
    for (final BookCopy c in _bookCopies) {
      if (c.id == copyId) {
        copy = c;
        break;
      }
    }
    if (copy == null) {
      return false;
    }
    copy
      ..branch = branch.trim()
      ..rack = rack.trim();
    _log('Copy Transferred', '${copy.accessionNumber} to ${copy.branch}/${copy.rack}');
    _persistAndNotify();
    return true;
  }

  bool updateCopyStatus(String copyId, CopyStatus newStatus) {
    if (!canManageBooks || newStatus == CopyStatus.issued) {
      return false;
    }

    BookCopy? copy;
    for (final BookCopy c in _bookCopies) {
      if (c.id == copyId) {
        copy = c;
        break;
      }
    }
    if (copy == null || copy.status == CopyStatus.issued) {
      return false;
    }
    if (copy.status == newStatus) {
      return true;
    }

    final Book? book = getBookById(copy.bookId);
    if (book == null) {
      return false;
    }

    switch (copy.status) {
      case CopyStatus.available:
        if (book.availableCopies <= 0) {
          return false;
        }
        book.availableCopies -= 1;
        break;
      case CopyStatus.damaged:
        if (book.damagedCopies <= 0) {
          return false;
        }
        book.damagedCopies -= 1;
        break;
      case CopyStatus.lost:
        if (book.lostCopies <= 0) {
          return false;
        }
        book.lostCopies -= 1;
        break;
      case CopyStatus.issued:
        return false;
    }

    switch (newStatus) {
      case CopyStatus.available:
        book.availableCopies += 1;
        break;
      case CopyStatus.damaged:
        book.damagedCopies += 1;
        break;
      case CopyStatus.lost:
        book.lostCopies += 1;
        break;
      case CopyStatus.issued:
        return false;
    }

    copy.status = newStatus;
    _log('Copy Status Updated', '${copy.accessionNumber} => ${newStatus.key}');
    _persistAndNotify();
    return true;
  }

  void addLedgerEntry({
    required String memberId,
    required LedgerEntryType type,
    required double amount,
    String referenceId = '',
    String description = '',
    LedgerApprovalStatus approvalStatus = LedgerApprovalStatus.approved,
  }) {
    if (!canManageMembers || amount <= 0) {
      return;
    }
    _ledgerEntries.insert(
      0,
      MemberLedgerEntry(
        id: _uuid.v4(),
        memberId: memberId,
        type: type,
        amount: amount,
        createdOn: DateTime.now(),
        referenceId: referenceId,
        description: description,
        approvalStatus: approvalStatus,
      ),
    );
    _log('Ledger Entry Added', 'Member=$memberId Type=${type.key} Amount=$amount');
    _persistAndNotify();
  }

  void addPenalty({
    required String memberId,
    required double amount,
    String description = '',
    String referenceId = '',
    bool requiresApproval = true,
  }) {
    addLedgerEntry(
      memberId: memberId,
      type: LedgerEntryType.penalty,
      amount: amount,
      referenceId: referenceId,
      description: description,
      approvalStatus: requiresApproval
          ? LedgerApprovalStatus.pending
          : LedgerApprovalStatus.approved,
    );
  }

  bool approveLedgerEntry(String entryId) {
    MemberLedgerEntry? entry;
    for (final MemberLedgerEntry e in _ledgerEntries) {
      if (e.id == entryId) {
        entry = e;
        break;
      }
    }
    if (entry == null || entry.approvalStatus == LedgerApprovalStatus.approved) {
      return false;
    }
    entry.approvalStatus = LedgerApprovalStatus.approved;
    _log('Penalty Approved', 'Entry=$entryId');
    _persistAndNotify();
    return true;
  }

  List<Book> searchBooks(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return books.toList();
    }

    return _books
        .where(
          (Book book) =>
              book.title.toLowerCase().contains(q) ||
              book.author.toLowerCase().contains(q) ||
              book.isbn.toLowerCase().contains(q) ||
              book.category.toLowerCase().contains(q) ||
              book.branch.toLowerCase().contains(q) ||
              book.rack.toLowerCase().contains(q) ||
              book.publisher.toLowerCase().contains(q) ||
              book.language.toLowerCase().contains(q) ||
              book.description.toLowerCase().contains(q) ||
              book.tags.any((String tag) => tag.toLowerCase().contains(q)),
        )
        .toList();
  }

  List<Member> searchMembers(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return members.toList();
    }

    return _members
        .where(
          (Member member) =>
              member.name.toLowerCase().contains(q) ||
              member.email.toLowerCase().contains(q) ||
              member.phone.toLowerCase().contains(q) ||
              member.membershipId.toLowerCase().contains(q) ||
              member.department.toLowerCase().contains(q) ||
              member.membershipType.toLowerCase().contains(q) ||
              member.status.toLowerCase().contains(q) ||
              member.notes.toLowerCase().contains(q),
        )
        .toList();
  }

  void addMember({
    required String name,
    required String email,
    required String phone,
    String membershipId = '',
    String membershipType = 'General',
    String department = '',
    String address = '',
    String status = 'Active',
    DateTime? expiryDate,
    String notes = '',
    int? maxBooksOverride,
  }) {
    if (!canManageMembers) {
      return;
    }
    _members.add(
      Member(
        id: _uuid.v4(),
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        joinedOn: DateTime.now(),
        membershipId: membershipId.trim(),
        membershipType: membershipType.trim().isEmpty ? 'General' : membershipType.trim(),
        department: department.trim(),
        address: address.trim(),
        status: status.trim().isEmpty ? 'Active' : status.trim(),
        expiryDate: expiryDate,
        notes: notes.trim(),
        maxBooksOverride: maxBooksOverride != null && maxBooksOverride > 0
            ? maxBooksOverride
            : null,
      ),
    );
    _log('Member Added', '$name ($email)');
    _persistAndNotify();
  }

  void updateMember(
    String id, {
    required String name,
    required String email,
    required String phone,
    String membershipId = '',
    String membershipType = 'General',
    String department = '',
    String address = '',
    String status = 'Active',
    DateTime? expiryDate,
    String notes = '',
    int? maxBooksOverride,
  }) {
    if (!canManageMembers) {
      return;
    }
    final Member? member = getMemberById(id);
    if (member == null) {
      return;
    }

    member
      ..name = name.trim()
      ..email = email.trim()
      ..phone = phone.trim()
      ..membershipId = membershipId.trim()
      ..membershipType = membershipType.trim().isEmpty ? 'General' : membershipType.trim()
      ..department = department.trim()
      ..address = address.trim()
      ..status = status.trim().isEmpty ? 'Active' : status.trim()
      ..expiryDate = expiryDate
      ..notes = notes.trim()
      ..maxBooksOverride = maxBooksOverride != null && maxBooksOverride > 0
          ? maxBooksOverride
          : null;

    _log('Member Updated', '${member.name} (${member.email})');
    _persistAndNotify();
  }

  bool deleteMember(String id) {
    if (!canManageMembers) {
      return false;
    }
    final Member? member = getMemberById(id);
    final bool hasActiveIssues =
        activeBorrowRecords.any((BorrowRecord r) => r.memberId == id);
    if (hasActiveIssues) {
      return false;
    }

    _members.removeWhere((Member m) => m.id == id);
    _records.removeWhere((BorrowRecord r) => r.memberId == id);
    _log('Member Deleted', member?.name ?? id);
    _persistAndNotify();
    return true;
  }

  void updateSettings({
    required int defaultBorrowDays,
    required double finePerDay,
    required int maxBooksPerMember,
    required int maxRenewals,
    required bool blockIssueOnOutstandingBalance,
    required double maxOutstandingBalanceForIssue,
  }) {
    if (!canAccessSettings) {
      return;
    }
    if (
        defaultBorrowDays <= 0 ||
        finePerDay < 0 ||
        maxBooksPerMember <= 0 ||
        maxRenewals < 0 ||
        maxOutstandingBalanceForIssue < 0) {
      return;
    }
    _defaultBorrowDays = defaultBorrowDays;
    _finePerDay = finePerDay;
    _maxBooksPerMember = maxBooksPerMember;
    _maxRenewals = maxRenewals;
    _blockIssueOnOutstandingBalance = blockIssueOnOutstandingBalance;
    _maxOutstandingBalanceForIssue = maxOutstandingBalanceForIssue;
    _log(
      'Settings Updated',
      'BorrowDays=$_defaultBorrowDays Fine=$_finePerDay MaxBooks=$_maxBooksPerMember '
      'MaxRenewals=$_maxRenewals BlockOnBalance=$_blockIssueOnOutstandingBalance '
      'MaxOutstanding=$_maxOutstandingBalanceForIssue',
    );
    _persistAndNotify();
  }

  String issueBook({
    required String bookId,
    required String memberId,
    int? borrowDays,
    String? specificCopyId,
  }) {
    if (!canManageCirculation) {
      return 'Permission denied for current role.';
    }
    final Book? book = getBookById(bookId);
    final Member? member = getMemberById(memberId);

    if (book == null || member == null) {
      return 'Selected book/member does not exist.';
    }
    if (member.status.toLowerCase() != 'active') {
      return 'Member account is not active.';
    }
    if (member.expiryDate != null && member.expiryDate!.isBefore(DateTime.now())) {
      return 'Member account is expired.';
    }
    if (_blockIssueOnOutstandingBalance) {
      final double balance = memberBalance(memberId);
      if (balance > _maxOutstandingBalanceForIssue) {
        return 'Member outstanding balance exceeds allowed limit.';
      }
    }
    final int activeForMember = activeIssuedCountForMember(memberId);
    final int effectiveMax = effectiveMaxBooksForMember(memberId);
    if (activeForMember >= effectiveMax) {
      return 'Member already reached max issue limit ($effectiveMax).';
    }
    if (book.availableCopies <= 0) {
      return 'No available copies for this book.';
    }

    final bool alreadyIssued = activeBorrowRecords
        .any((BorrowRecord r) => r.bookId == bookId && r.memberId == memberId);
    if (alreadyIssued) {
      return 'This member already has this book issued.';
    }

    BookCopy? selectedCopy;
    if (specificCopyId != null && specificCopyId.trim().isNotEmpty) {
      for (final BookCopy copy in _bookCopies) {
        if (copy.id == specificCopyId && copy.bookId == bookId) {
          selectedCopy = copy;
          break;
        }
      }
      if (selectedCopy == null || selectedCopy.status != CopyStatus.available) {
        return 'Selected copy is not available.';
      }
    } else {
      for (final BookCopy copy in _bookCopies) {
        if (copy.bookId == bookId && copy.status == CopyStatus.available) {
          selectedCopy = copy;
          break;
        }
      }
    }

    if (selectedCopy == null) {
      return 'No physical copy available for this book.';
    }

    selectedCopy.status = CopyStatus.issued;
    book.availableCopies -= 1;
    final int issueDays = borrowDays ?? _defaultBorrowDays;
    _records.add(
      BorrowRecord(
        id: _uuid.v4(),
        bookId: bookId,
        memberId: memberId,
        copyId: selectedCopy.id,
        issuedOn: DateTime.now(),
        dueOn: DateTime.now().add(Duration(days: issueDays)),
      ),
    );

    _log(
      'Book Issued',
      'Book=$bookId Member=$memberId Days=$issueDays Copy=${selectedCopy.accessionNumber}',
    );

    final List<String>? waitlist = _waitlistByBook[bookId];
    if (waitlist != null) {
      waitlist.remove(memberId);
      if (waitlist.isEmpty) {
        _waitlistByBook.remove(bookId);
      }
    }

    _persistAndNotify();
    return 'Book issued successfully.';
  }

  int overdueDaysForRecord(BorrowRecord record) {
    final DateTime endDate = record.returnedOn ?? DateTime.now();
    final int diff = endDate.difference(record.dueOn).inDays;
    return max(diff, 0);
  }

  double totalFineForRecord(BorrowRecord record) {
    return overdueDaysForRecord(record) * _finePerDay;
  }

  double pendingFineForRecord(BorrowRecord record) {
    final double pending = totalFineForRecord(record) - record.finePaid;
    return pending > 0 ? pending : 0;
  }

  bool returnBook(String recordId, {double paidAmount = 0}) {
    if (!canManageCirculation) {
      return false;
    }
    BorrowRecord? record;
    for (final BorrowRecord r in _records) {
      if (r.id == recordId) {
        record = r;
        break;
      }
    }
    if (record == null || record.isReturned) {
      return false;
    }

    record.returnedOn = DateTime.now();
    final double calculatedFine = totalFineForRecord(record);
    final double payNow = paidAmount > calculatedFine ? calculatedFine : paidAmount;
    if (calculatedFine > 0) {
      addPenalty(
        memberId: record.memberId,
        amount: calculatedFine,
        description: 'Overdue fine for record $recordId',
        referenceId: recordId,
        requiresApproval: false,
      );
      if (payNow > 0) {
        addLedgerEntry(
          memberId: record.memberId,
          type: LedgerEntryType.payment,
          amount: payNow,
          referenceId: recordId,
          description: 'Fine payment on return',
          approvalStatus: LedgerApprovalStatus.approved,
        );
      }
    }
    if (payNow > 0) {
      record.finePaid += payNow;
    }
    final Book? book = getBookById(record.bookId);
    if (book != null && book.availableCopies < book.totalCopies) {
      book.availableCopies += 1;
    }

    if (record.copyId != null) {
      for (final BookCopy copy in _bookCopies) {
        if (copy.id == record.copyId && copy.status == CopyStatus.issued) {
          copy.status = CopyStatus.available;
          break;
        }
      }
    }

    _autoIssueFromWaitlist(record.bookId);

    _log('Book Returned', 'Record=$recordId Paid=$payNow');

    _persistAndNotify();
    return true;
  }

  bool renewBorrow(String recordId, {int extraDays = 7}) {
    if (!canManageCirculation) {
      return false;
    }
    if (extraDays <= 0) {
      return false;
    }

    BorrowRecord? record;
    for (final BorrowRecord r in _records) {
      if (r.id == recordId) {
        record = r;
        break;
      }
    }
    if (record == null || record.isReturned) {
      return false;
    }
    if (record.renewCount >= _maxRenewals) {
      return false;
    }

    final List<String> waitlist = _waitlistByBook[record.bookId] ?? <String>[];
    if (waitlist.isNotEmpty) {
      return false;
    }

    record
      ..renewCount += 1
      ..finePaid = record.finePaid
      ..returnedOn = null;

    final DateTime baseDue = record.dueOn.isAfter(DateTime.now()) ? record.dueOn : DateTime.now();
    final BorrowRecord replacement = BorrowRecord(
      id: record.id,
      bookId: record.bookId,
      memberId: record.memberId,
      copyId: record.copyId,
      issuedOn: record.issuedOn,
      dueOn: baseDue.add(Duration(days: extraDays)),
      returnedOn: null,
      finePaid: record.finePaid,
      renewCount: record.renewCount,
    );

    final int index = _records.indexOf(record);
    _records[index] = replacement;

    _log('Borrow Renewed', 'Record=$recordId ExtraDays=$extraDays');
    _persistAndNotify();
    return true;
  }

  String placeReservation({required String bookId, required String memberId}) {
    if (!canManageCirculation) {
      return 'Permission denied for current role.';
    }
    final Book? book = getBookById(bookId);
    final Member? member = getMemberById(memberId);
    if (book == null || member == null) {
      return 'Selected book/member does not exist.';
    }

    final bool alreadyIssued = activeBorrowRecords
        .any((BorrowRecord r) => r.bookId == bookId && r.memberId == memberId);
    if (alreadyIssued) {
      return 'This member already has this book.';
    }

    final List<String> queue = _waitlistByBook.putIfAbsent(bookId, () => <String>[]);
    if (queue.contains(memberId)) {
      return 'Member is already in the waitlist.';
    }

    queue.add(memberId);
    _log('Reservation Added', 'Book=$bookId Member=$memberId');
    _persistAndNotify();
    return 'Reservation added to waitlist.';
  }

  bool cancelReservation({required String bookId, required String memberId}) {
    if (!canManageCirculation) {
      return false;
    }
    final List<String>? queue = _waitlistByBook[bookId];
    if (queue == null) {
      return false;
    }
    final bool removed = queue.remove(memberId);
    if (queue.isEmpty) {
      _waitlistByBook.remove(bookId);
    }
    if (removed) {
      _log('Reservation Removed', 'Book=$bookId Member=$memberId');
      _persistAndNotify();
    }
    return removed;
  }

  String exportRecordsCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'recordId,bookTitle,isbn,memberName,issuedOn,dueOn,returnedOn,renewals,totalFine,finePaid,pendingFine,status',
    );

    for (final BorrowRecord record in _records) {
      final Book? book = getBookById(record.bookId);
      final Member? member = getMemberById(record.memberId);
      final String status = record.isReturned
          ? 'Returned'
          : (record.isOverdue ? 'Overdue' : 'Active');
      final double totalFine = totalFineForRecord(record);
      final double pending = pendingFineForRecord(record);

      buffer.writeln(
        '${_csv(record.id)},${_csv(book?.title ?? 'Unknown')},${_csv(book?.isbn ?? '')},'
        '${_csv(member?.name ?? 'Unknown')},${_csv(record.issuedOn.toIso8601String())},'
        '${_csv(record.dueOn.toIso8601String())},${_csv(record.returnedOn?.toIso8601String() ?? '')},'
        '${_csv(record.renewCount.toString())},${_csv(totalFine.toStringAsFixed(2))},'
        '${_csv(record.finePaid.toStringAsFixed(2))},${_csv(pending.toStringAsFixed(2))},'
        '${_csv(status)}',
      );
    }

    return buffer.toString();
  }

  String _csv(String value) {
    final String escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String exportVendorsCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('id,name,contactPerson,email,phone,address,gstNumber,paymentTerms,rating');
    for (final Vendor vendor in _vendors) {
      buffer.writeln(
        '${_csv(vendor.id)},${_csv(vendor.name)},${_csv(vendor.contactPerson)},'
        '${_csv(vendor.email)},${_csv(vendor.phone)},${_csv(vendor.address)},'
        '${_csv(vendor.gstNumber)},${_csv(vendor.paymentTerms)},${_csv(vendor.rating.toString())}',
      );
    }
    return buffer.toString();
  }

  String exportCopiesCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('id,accessionNumber,bookId,bookTitle,branch,rack,status,addedOn');
    for (final BookCopy copy in _bookCopies) {
      final Book? book = getBookById(copy.bookId);
      buffer.writeln(
        '${_csv(copy.id)},${_csv(copy.accessionNumber)},${_csv(copy.bookId)},'
        '${_csv(book?.title ?? 'Unknown')},${_csv(copy.branch)},${_csv(copy.rack)},'
        '${_csv(copy.status.key)},${_csv(copy.addedOn.toIso8601String())}',
      );
    }
    return buffer.toString();
  }

  String exportLedgerCsv({String? memberId}) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('id,memberId,memberName,type,amount,approvalStatus,referenceId,description,createdOn');
    Iterable<MemberLedgerEntry> source = _ledgerEntries;
    if (memberId != null && memberId.trim().isNotEmpty) {
      source = source.where((MemberLedgerEntry entry) => entry.memberId == memberId);
    }
    for (final MemberLedgerEntry entry in source) {
      final Member? member = getMemberById(entry.memberId);
      buffer.writeln(
        '${_csv(entry.id)},${_csv(entry.memberId)},${_csv(member?.name ?? 'Unknown')},'
        '${_csv(entry.type.key)},${_csv(entry.amount.toStringAsFixed(2))},'
        '${_csv(entry.approvalStatus.key)},${_csv(entry.referenceId)},${_csv(entry.description)},'
        '${_csv(entry.createdOn.toIso8601String())}',
      );
    }
    return buffer.toString();
  }

  String exportBooksCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'title,author,isbn,totalCopies,category,branch,rack,publisher,edition,language,publishedYear,unitPrice,reorderLevel,tags,description',
    );
    for (final Book book in _books) {
      buffer.writeln(
        '${_csv(book.title)},${_csv(book.author)},${_csv(book.isbn)},${_csv(book.totalCopies.toString())},'
        '${_csv(book.category)},${_csv(book.branch)},${_csv(book.rack)},${_csv(book.publisher)},'
        '${_csv(book.edition)},${_csv(book.language)},${_csv(book.publishedYear?.toString() ?? '')},'
        '${_csv(book.unitPrice.toStringAsFixed(2))},${_csv(book.reorderLevel.toString())},'
        '${_csv(book.tags.join('|'))},${_csv(book.description)}',
      );
    }
    return buffer.toString();
  }

  List<List<String>> _parseCsvRows(String csv) {
    final List<List<String>> rows = <List<String>>[];
    final String normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final StringBuffer field = StringBuffer();
    List<String> row = <String>[];
    bool inQuotes = false;

    for (int i = 0; i < normalized.length; i++) {
      final String ch = normalized[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < normalized.length && normalized[i + 1] == '"') {
          field.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (ch == ',' && !inQuotes) {
        row.add(field.toString().trim());
        field.clear();
        continue;
      }

      if (ch == '\n' && !inQuotes) {
        row.add(field.toString().trim());
        field.clear();
        if (row.any((String value) => value.isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
        continue;
      }

      field.write(ch);
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString().trim());
      if (row.any((String value) => value.isNotEmpty)) {
        rows.add(row);
      }
    }

    return rows;
  }

  String importMembersCsv(String csv, {bool updateExisting = true}) {
    if (!canManageMembers) {
      return 'Permission denied for current role.';
    }
    final List<List<String>> rows = _parseCsvRows(csv);
    if (rows.length < 2) {
      return 'CSV must include a header and at least one data row.';
    }

    final List<String> header = rows.first.map((String h) => h.toLowerCase()).toList();
    int indexOf(String key) => header.indexOf(key.toLowerCase());

    final int iName = indexOf('name');
    final int iEmail = indexOf('email');
    final int iPhone = indexOf('phone');
    if (iName == -1 || iEmail == -1 || iPhone == -1) {
      return 'Required headers missing. Required: name,email,phone';
    }

    final int iMembershipId = indexOf('membershipid');
    final int iMembershipType = indexOf('membershiptype');
    final int iDepartment = indexOf('department');
    final int iAddress = indexOf('address');
    final int iStatus = indexOf('status');
    final int iExpiryDate = indexOf('expirydate');
    final int iNotes = indexOf('notes');
    final int iMaxOverride = indexOf('maxbooksoverride');

    int created = 0;
    int updated = 0;
    int skipped = 0;
    final List<String> errors = <String>[];

    for (int r = 1; r < rows.length; r++) {
      final List<String> row = rows[r];
      String valueAt(int idx) => idx >= 0 && idx < row.length ? row[idx].trim() : '';

      final String name = valueAt(iName);
      final String email = valueAt(iEmail);
      final String phone = valueAt(iPhone);
      if (name.isEmpty || email.isEmpty || phone.isEmpty) {
        skipped += 1;
        errors.add('Row ${r + 1}: name/email/phone required.');
        continue;
      }

      DateTime? expiryDate;
      final String expiryRaw = valueAt(iExpiryDate);
      if (expiryRaw.isNotEmpty) {
        expiryDate = DateTime.tryParse(expiryRaw);
        if (expiryDate == null) {
          skipped += 1;
          errors.add('Row ${r + 1}: invalid expiryDate format (use YYYY-MM-DD).');
          continue;
        }
      }

      final String membershipId = valueAt(iMembershipId);
      final String membershipType = valueAt(iMembershipType);
      final String department = valueAt(iDepartment);
      final String address = valueAt(iAddress);
      final String status = valueAt(iStatus);
      final String notes = valueAt(iNotes);
      final int? maxBooksOverride = int.tryParse(valueAt(iMaxOverride));

      Member? existing;
      if (updateExisting) {
        for (final Member member in _members) {
          final bool sameMembershipId = membershipId.isNotEmpty &&
              member.membershipId.toLowerCase() == membershipId.toLowerCase();
          final bool sameEmail = member.email.toLowerCase() == email.toLowerCase();
          if (sameMembershipId || sameEmail) {
            existing = member;
            break;
          }
        }
      }

      if (existing == null) {
        _members.add(
          Member(
            id: _uuid.v4(),
            name: name,
            email: email,
            phone: phone,
            joinedOn: DateTime.now(),
            membershipId: membershipId,
            membershipType: membershipType.isEmpty ? 'General' : membershipType,
            department: department,
            address: address,
            status: status.isEmpty ? 'Active' : status,
            expiryDate: expiryDate,
            notes: notes,
            maxBooksOverride: maxBooksOverride,
          ),
        );
        created += 1;
      } else {
        existing
          ..name = name
          ..email = email
          ..phone = phone
          ..membershipId = membershipId
          ..membershipType = membershipType.isEmpty ? existing.membershipType : membershipType
          ..department = department
          ..address = address
          ..status = status.isEmpty ? existing.status : status
          ..expiryDate = expiryDate
          ..notes = notes
          ..maxBooksOverride = maxBooksOverride != null && maxBooksOverride > 0
              ? maxBooksOverride
              : null;
        updated += 1;
      }
    }

    _log('Members CSV Imported', 'Created=$created Updated=$updated Skipped=$skipped');
    _persistAndNotify();

    final String errorPreview = errors.isEmpty
        ? ''
        : ' Errors: ${errors.take(3).join(' | ')}${errors.length > 3 ? ' ...' : ''}';
    return 'Members import complete. Created: $created, Updated: $updated, Skipped: $skipped.$errorPreview';
  }

  String importVendorsCsv(String csv, {bool updateExisting = true}) {
    if (!canManageBooks) {
      return 'Permission denied for current role.';
    }
    final List<List<String>> rows = _parseCsvRows(csv);
    if (rows.length < 2) {
      return 'CSV must include a header and at least one data row.';
    }

    final List<String> header = rows.first.map((String h) => h.toLowerCase()).toList();
    int indexOf(String key) => header.indexOf(key.toLowerCase());
    final int iName = indexOf('name');
    if (iName == -1) {
      return 'Required header missing: name';
    }

    final int iContact = indexOf('contactperson');
    final int iEmail = indexOf('email');
    final int iPhone = indexOf('phone');
    final int iAddress = indexOf('address');
    final int iGst = indexOf('gstnumber');
    final int iTerms = indexOf('paymentterms');
    final int iRating = indexOf('rating');

    int created = 0;
    int updated = 0;
    int skipped = 0;
    final List<String> errors = <String>[];

    for (int r = 1; r < rows.length; r++) {
      final List<String> row = rows[r];
      String valueAt(int idx) => idx >= 0 && idx < row.length ? row[idx].trim() : '';

      final String name = valueAt(iName);
      if (name.isEmpty) {
        skipped += 1;
        errors.add('Row ${r + 1}: vendor name required.');
        continue;
      }

      int rating = 0;
      final String ratingRaw = valueAt(iRating);
      if (ratingRaw.isNotEmpty) {
        final int? parsed = int.tryParse(ratingRaw);
        if (parsed == null || parsed < 0 || parsed > 5) {
          skipped += 1;
          errors.add('Row ${r + 1}: rating must be 0-5.');
          continue;
        }
        rating = parsed;
      }

      Vendor? existing;
      if (updateExisting) {
        for (final Vendor vendor in _vendors) {
          if (vendor.name.toLowerCase() == name.toLowerCase()) {
            existing = vendor;
            break;
          }
        }
      }

      if (existing == null) {
        _vendors.add(
          Vendor(
            id: _uuid.v4(),
            name: name,
            contactPerson: valueAt(iContact),
            email: valueAt(iEmail),
            phone: valueAt(iPhone),
            address: valueAt(iAddress),
            gstNumber: valueAt(iGst),
            paymentTerms: valueAt(iTerms),
            rating: rating,
          ),
        );
        created += 1;
      } else {
        existing
          ..name = name
          ..contactPerson = valueAt(iContact)
          ..email = valueAt(iEmail)
          ..phone = valueAt(iPhone)
          ..address = valueAt(iAddress)
          ..gstNumber = valueAt(iGst)
          ..paymentTerms = valueAt(iTerms)
          ..rating = rating;
        updated += 1;
      }
    }

    _log('Vendors CSV Imported', 'Created=$created Updated=$updated Skipped=$skipped');
    _persistAndNotify();

    final String errorPreview = errors.isEmpty
        ? ''
        : ' Errors: ${errors.take(3).join(' | ')}${errors.length > 3 ? ' ...' : ''}';
    return 'Vendors import complete. Created: $created, Updated: $updated, Skipped: $skipped.$errorPreview';
  }

  String importBooksCsv(String csv, {bool updateExisting = true}) {
    if (!canManageBooks) {
      return 'Permission denied for current role.';
    }
    final List<List<String>> rows = _parseCsvRows(csv);
    if (rows.length < 2) {
      return 'CSV must include a header and at least one data row.';
    }

    final List<String> header = rows.first.map((String h) => h.toLowerCase()).toList();
    int indexOf(String key) => header.indexOf(key.toLowerCase());

    final int iTitle = indexOf('title');
    final int iAuthor = indexOf('author');
    final int iIsbn = indexOf('isbn');
    final int iTotalCopies = indexOf('totalcopies');
    if (iTitle == -1 || iAuthor == -1 || iIsbn == -1 || iTotalCopies == -1) {
      return 'Required headers missing. Required: title,author,isbn,totalCopies';
    }

    final int iCategory = indexOf('category');
    final int iBranch = indexOf('branch');
    final int iRack = indexOf('rack');
    final int iPublisher = indexOf('publisher');
    final int iEdition = indexOf('edition');
    final int iLanguage = indexOf('language');
    final int iPublishedYear = indexOf('publishedyear');
    final int iUnitPrice = indexOf('unitprice');
    final int iReorderLevel = indexOf('reorderlevel');
    final int iTags = indexOf('tags');
    final int iDescription = indexOf('description');

    int created = 0;
    int updated = 0;
    int skipped = 0;
    final List<String> errors = <String>[];

    for (int r = 1; r < rows.length; r++) {
      final List<String> row = rows[r];
      String valueAt(int idx) => idx >= 0 && idx < row.length ? row[idx].trim() : '';

      final String title = valueAt(iTitle);
      final String author = valueAt(iAuthor);
      final String isbn = valueAt(iIsbn);
      final int? totalCopies = int.tryParse(valueAt(iTotalCopies));
      if (title.isEmpty || author.isEmpty || isbn.isEmpty || totalCopies == null || totalCopies <= 0) {
        skipped += 1;
        errors.add('Row ${r + 1}: title/author/isbn/totalCopies invalid.');
        continue;
      }

      final int? publishedYear = valueAt(iPublishedYear).isEmpty
          ? null
          : int.tryParse(valueAt(iPublishedYear));
      if (valueAt(iPublishedYear).isNotEmpty && publishedYear == null) {
        skipped += 1;
        errors.add('Row ${r + 1}: publishedYear must be numeric.');
        continue;
      }

      final double unitPrice = double.tryParse(valueAt(iUnitPrice)) ?? 0;
      final int reorderLevel = int.tryParse(valueAt(iReorderLevel)) ?? 1;
        final List<String> tags = valueAt(iTags)
          .split('|')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList();
        final String description = valueAt(iDescription);

      Book? existing;
      if (updateExisting) {
        for (final Book book in _books) {
          if (book.isbn.toLowerCase() == isbn.toLowerCase()) {
            existing = book;
            break;
          }
        }
      }

      if (existing == null) {
        addBook(
          title: title,
          author: author,
          isbn: isbn,
          totalCopies: totalCopies,
          category: valueAt(iCategory),
          branch: valueAt(iBranch),
          rack: valueAt(iRack),
          publisher: valueAt(iPublisher),
          edition: valueAt(iEdition),
          language: valueAt(iLanguage),
          publishedYear: publishedYear,
          unitPrice: unitPrice,
          reorderLevel: reorderLevel,
          tags: tags,
          description: description,
        );
        created += 1;
      } else {
        updateBook(
          existing.id,
          title: title,
          author: author,
          isbn: isbn,
          totalCopies: totalCopies,
          category: valueAt(iCategory),
          branch: valueAt(iBranch),
          rack: valueAt(iRack),
          publisher: valueAt(iPublisher),
          edition: valueAt(iEdition),
          language: valueAt(iLanguage),
          publishedYear: publishedYear,
          unitPrice: unitPrice,
          reorderLevel: reorderLevel,
          tags: tags,
          description: description,
        );
        updated += 1;
      }
    }

    _log('Books CSV Imported', 'Created=$created Updated=$updated Skipped=$skipped');
    _persistAndNotify();

    final String errorPreview = errors.isEmpty
        ? ''
        : ' Errors: ${errors.take(3).join(' | ')}${errors.length > 3 ? ' ...' : ''}';
    return 'Books import complete. Created: $created, Updated: $updated, Skipped: $skipped.$errorPreview';
  }

  void _autoIssueFromWaitlist(String bookId) {
    final Book? book = getBookById(bookId);
    if (book == null || book.availableCopies <= 0) {
      return;
    }
    final List<String>? queue = _waitlistByBook[bookId];
    if (queue == null || queue.isEmpty) {
      return;
    }

    for (int i = 0; i < queue.length; i++) {
      final String memberId = queue[i];
      final String result = issueBook(
        bookId: bookId,
        memberId: memberId,
        borrowDays: _defaultBorrowDays,
      );
      if (result.toLowerCase().contains('success')) {
        if (queue.isEmpty) {
          _waitlistByBook.remove(bookId);
        }
        break;
      }
    }
  }

  bool collectFine(String recordId, double amount) {
    if (!canManageCirculation) {
      return false;
    }
    if (amount <= 0) {
      return false;
    }

    BorrowRecord? record;
    for (final BorrowRecord r in _records) {
      if (r.id == recordId) {
        record = r;
        break;
      }
    }
    if (record == null) {
      return false;
    }

    final double pending = pendingFineForRecord(record);
    if (pending <= 0) {
      return false;
    }

    final double collected = amount > pending ? pending : amount;
    record.finePaid += collected;
    addLedgerEntry(
      memberId: record.memberId,
      type: LedgerEntryType.payment,
      amount: collected,
      referenceId: record.id,
      description: 'Fine payment collection',
      approvalStatus: LedgerApprovalStatus.approved,
    );
    _log('Fine Collected', 'Record=$recordId Amount=$amount');
    _persistAndNotify();
    return true;
  }

  List<BorrowRecord> searchRecords(String query, {required bool includeHistory}) {
    final String q = query.trim().toLowerCase();
    final List<BorrowRecord> source = includeHistory ? records.toList() : activeBorrowRecords;
    if (q.isEmpty) {
      return source;
    }

    return source.where((BorrowRecord record) {
      final Book? book = getBookById(record.bookId);
      final Member? member = getMemberById(record.memberId);
      final String bookTitle = book?.title.toLowerCase() ?? '';
      final String memberName = member?.name.toLowerCase() ?? '';
      final String isbn = book?.isbn.toLowerCase() ?? '';
      return bookTitle.contains(q) || memberName.contains(q) || isbn.contains(q);
    }).toList();
  }

  List<BorrowRecord> recordsByDateRange({
    DateTime? from,
    DateTime? to,
  }) {
    return _records.where((BorrowRecord record) {
      final DateTime date = record.issuedOn;
      final bool inFrom = from == null || !date.isBefore(DateTime(from.year, from.month, from.day));
      final bool inTo = to == null || !date.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
      return inFrom && inTo;
    }).toList();
  }

  List<MapEntry<Book, int>> topBooks({int limit = 5}) {
    final Map<String, int> count = <String, int>{};
    for (final BorrowRecord record in _records) {
      count.update(record.bookId, (int value) => value + 1, ifAbsent: () => 1);
    }

    final List<MapEntry<Book, int>> result = <MapEntry<Book, int>>[];
    for (final MapEntry<String, int> entry in count.entries) {
      final Book? book = getBookById(entry.key);
      if (book != null) {
        result.add(MapEntry<Book, int>(book, entry.value));
      }
    }

    result.sort((MapEntry<Book, int> a, MapEntry<Book, int> b) => b.value.compareTo(a.value));
    return result.take(limit).toList();
  }

  List<MapEntry<Member, int>> topMembers({int limit = 5}) {
    final Map<String, int> count = <String, int>{};
    for (final BorrowRecord record in _records) {
      count.update(record.memberId, (int value) => value + 1, ifAbsent: () => 1);
    }

    final List<MapEntry<Member, int>> result = <MapEntry<Member, int>>[];
    for (final MapEntry<String, int> entry in count.entries) {
      final Member? member = getMemberById(entry.key);
      if (member != null) {
        result.add(MapEntry<Member, int>(member, entry.value));
      }
    }

    result.sort((MapEntry<Member, int> a, MapEntry<Member, int> b) => b.value.compareTo(a.value));
    return result.take(limit).toList();
  }

  List<Book> lowStockBooks({int threshold = 1}) {
    return _books
        .where(
          (Book book) => book.availableCopies <= (book.reorderLevel > 0 ? book.reorderLevel : threshold),
        )
        .toList();
  }

  Map<String, int> monthlyIssueStats({int monthCount = 6}) {
    final DateTime now = DateTime.now();
    final Map<String, int> result = <String, int>{};

    for (int i = monthCount - 1; i >= 0; i--) {
      final DateTime month = DateTime(now.year, now.month - i, 1);
      final String key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      result[key] = 0;
    }

    for (final BorrowRecord record in _records) {
      final String key =
          '${record.issuedOn.year}-${record.issuedOn.month.toString().padLeft(2, '0')}';
      if (result.containsKey(key)) {
        result[key] = (result[key] ?? 0) + 1;
      }
    }

    return result;
  }

  String exportFullStateJson() {
    final Map<String, dynamic> data = _toStateMap();
    data['exportedAt'] = DateTime.now().toIso8601String();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String importFullStateJson(String rawJson) {
    if (!canAccessSettings) {
      return 'Import denied for current role.';
    }
    try {
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(jsonDecode(rawJson) as Map<dynamic, dynamic>);
      _applyStateMap(json);
      _log('Data Imported', 'Full state restored from JSON');
      _persistAndNotify();
      return 'Import completed successfully.';
    } catch (_) {
      return 'Import failed: invalid JSON structure.';
    }
  }

  Future<void> resetAllData({bool reseed = true}) async {
    if (!canAccessSettings) {
      return;
    }
    _books.clear();
    _members.clear();
    _records.clear();
    _waitlistByBook.clear();

    if (reseed) {
      _seedData();
    }
    _log('Data Reset', 'All records cleared. Reseed=$reseed');
    _persistAndNotify();
  }

  String exportAuditCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('id,timestamp,role,action,details');
    for (final AuditLog log in _auditLogs) {
      buffer.writeln(
        '${_csv(log.id)},${_csv(log.timestamp.toIso8601String())},${_csv(log.role)},${_csv(log.action)},${_csv(log.details)}',
      );
    }
    return buffer.toString();
  }

  /// Lookup a copy by accession number. Returns null if not found.
  BookCopy? lookupCopyByAccession(String accessionNumber) {
    final String q = accessionNumber.trim().toLowerCase();
    for (final BookCopy copy in _bookCopies) {
      if (copy.accessionNumber.toLowerCase() == q) {
        return copy;
      }
    }
    return null;
  }

  /// Quick return a single copy by accession number.
  String quickReturnByAccession(String accessionNumber) {
    final BookCopy? copy = lookupCopyByAccession(accessionNumber);
    if (copy == null) {
      return 'Copy not found: $accessionNumber';
    }
    if (copy.status != CopyStatus.issued) {
      final Book? book = getBookById(copy.bookId);
      return 'Copy ${copy.accessionNumber} (${book?.title ?? copy.bookId}) is not currently issued.';
    }
    BorrowRecord? record;
    for (final BorrowRecord r in _records) {
      if (r.copyId == copy.id && !r.isReturned) {
        record = r;
        break;
      }
    }
    if (record == null) {
      return 'No active issue record found for this copy.';
    }
    final bool ok = returnBook(record.id);
    if (ok) {
      final Book? book = getBookById(copy.bookId);
      return 'Returned: "${book?.title ?? copy.bookId}" [${copy.accessionNumber}].';
    }
    return 'Return failed.';
  }

  /// Batch return multiple records by ID. Returns summary string.
  String batchReturnBooks(List<String> recordIds) {
    if (!canManageCirculation) {
      return 'Permission denied.';
    }
    int success = 0;
    int failed = 0;
    for (final String id in recordIds) {
      if (returnBook(id)) {
        success += 1;
      } else {
        failed += 1;
      }
    }
    return 'Batch return: $success returned, $failed skipped.';
  }

  /// Update only tags and description for a book.
  void updateBookMeta(String bookId, {List<String>? tags, String? description}) {
    if (!canManageBooks) {
      return;
    }
    final Book? book = getBookById(bookId);
    if (book == null) {
      return;
    }
    if (tags != null) {
      book.tags = tags.map((String t) => t.trim()).where((String t) => t.isNotEmpty).toList();
    }
    if (description != null) {
      book.description = description.trim();
    }
    _log('Book Meta Updated', '${book.title} tags/description');
    _persistAndNotify();
  }

  /// Update notes and per-member max books override.
  void updateMemberNotes(
    String memberId, {
    String? notes,
    int? maxBooksOverride,
  }) {
    if (!canManageMembers) {
      return;
    }
    final Member? member = getMemberById(memberId);
    if (member == null) {
      return;
    }
    if (notes != null) {
      member.notes = notes;
    }
    if (maxBooksOverride != null) {
      member.maxBooksOverride = maxBooksOverride <= 0 ? null : maxBooksOverride;
    }
    _log('Member Notes Updated', member.name);
    _persistAndNotify();
  }

  int effectiveMaxBooksForMember(String memberId) {
    final Member? member = getMemberById(memberId);
    if (member != null && member.maxBooksOverride != null && member.maxBooksOverride! > 0) {
      return member.maxBooksOverride!;
    }
    return _maxBooksPerMember;
  }

  void _seedData() {
    addBook(
      title: 'Clean Code',
      author: 'Robert C. Martin',
      isbn: '9780132350884',
      totalCopies: 4,
      category: 'Software Engineering',
      branch: 'Central Library',
      rack: 'SE-04',
      publisher: 'Prentice Hall',
      edition: '1st',
      language: 'English',
      publishedYear: 2008,
      acquisitionDate: DateTime.now().subtract(const Duration(days: 400)),
      unitPrice: 999,
    );
    addBook(
      title: 'Design Patterns',
      author: 'GoF',
      isbn: '9780201633610',
      totalCopies: 2,
      category: 'Software Engineering',
      branch: 'Central Library',
      rack: 'SE-12',
      publisher: 'Addison-Wesley',
      edition: '1st',
      language: 'English',
      publishedYear: 1994,
      acquisitionDate: DateTime.now().subtract(const Duration(days: 1200)),
      unitPrice: 1499,
    );
    addBook(
      title: 'Flutter in Action',
      author: 'Eric Windmill',
      isbn: '9781617296147',
      totalCopies: 3,
      category: 'Mobile Development',
      branch: 'Technology Wing',
      rack: 'MOB-03',
      publisher: 'Manning',
      edition: '1st',
      language: 'English',
      publishedYear: 2020,
      acquisitionDate: DateTime.now().subtract(const Duration(days: 240)),
      unitPrice: 1199,
    );

    addMember(
      name: 'Aarav Mehta',
      email: 'aarav@example.com',
      phone: '+91-9000011111',
      membershipId: 'MEM-1001',
      membershipType: 'Student',
      department: 'Computer Science',
      address: 'Ahmedabad',
      status: 'Active',
      expiryDate: DateTime.now().add(const Duration(days: 365)),
    );
    addMember(
      name: 'Sara Khan',
      email: 'sara@example.com',
      phone: '+91-9000022222',
      membershipId: 'MEM-1002',
      membershipType: 'Faculty',
      department: 'Information Systems',
      address: 'Mumbai',
      status: 'Active',
      expiryDate: DateTime.now().add(const Duration(days: 540)),
    );

    addVendor(
      name: 'TechBooks Distributors',
      contactPerson: 'Rohan Shah',
      email: 'sales@techbooks.example',
      phone: '+91-9011122233',
      paymentTerms: '30 days',
      rating: 4,
    );

    if (_books.length >= 2) {
      addAcquisition(
        bookId: _books[1].id,
        vendor: 'TechBooks Distributors',
        branch: 'Central Library',
        quantity: 1,
        unitCost: 1450,
        invoiceNumber: 'INV-1001',
        notes: 'Initial enterprise seed procurement',
      );
    }

    final String? firstBookId = _books.isNotEmpty ? _books.first.id : null;
    final String? firstMemberId = _members.isNotEmpty ? _members.first.id : null;

    if (firstBookId != null && firstMemberId != null) {
      issueBook(bookId: firstBookId, memberId: firstMemberId);
      addPenalty(
        memberId: firstMemberId,
        amount: 50,
        description: 'Reference charge pending approval',
        requiresApproval: true,
      );
    }
  }
}
