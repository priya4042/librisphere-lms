import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/member.dart';
import '../providers/library_provider.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final List<BorrowRecord> scoped = provider.recordsByDateRange(from: _from, to: _to);

    final int activeIssues = scoped.where((BorrowRecord r) => !r.isReturned).length;
    final int completed = scoped.where((BorrowRecord r) => r.isReturned).length;
    final int overdue = scoped.where((BorrowRecord r) => !r.isReturned && r.isOverdue).length;
    final double fineCollected = scoped.fold<double>(0, (double sum, BorrowRecord r) => sum + r.finePaid);
    final double fineOutstanding = scoped
        .where((BorrowRecord r) => !r.isReturned)
        .fold<double>(0, (double sum, BorrowRecord r) => sum + provider.pendingFineForRecord(r));

    final Map<String, int> topBookCounts = <String, int>{};
    final Map<String, int> topMemberCounts = <String, int>{};
    for (final BorrowRecord r in scoped) {
      topBookCounts.update(r.bookId, (int v) => v + 1, ifAbsent: () => 1);
      topMemberCounts.update(r.memberId, (int v) => v + 1, ifAbsent: () => 1);
    }

    final List<MapEntry<Book, int>> topBooks = topBookCounts.entries
        .map(
          (MapEntry<String, int> e) => MapEntry<Book?, int>(provider.getBookById(e.key), e.value),
        )
        .where((MapEntry<Book?, int> e) => e.key != null)
        .map((MapEntry<Book?, int> e) => MapEntry<Book, int>(e.key!, e.value))
        .toList()
      ..sort((MapEntry<Book, int> a, MapEntry<Book, int> b) => b.value.compareTo(a.value));

    final List<MapEntry<Member, int>> topMembers = topMemberCounts.entries
        .map(
          (MapEntry<String, int> e) => MapEntry<Member?, int>(provider.getMemberById(e.key), e.value),
        )
        .where((MapEntry<Member?, int> e) => e.key != null)
        .map((MapEntry<Member?, int> e) => MapEntry<Member, int>(e.key!, e.value))
        .toList()
      ..sort((MapEntry<Member, int> a, MapEntry<Member, int> b) => b.value.compareTo(a.value));

    final List<Book> lowStock = provider.lowStockBooks(threshold: 1);
    final List<Book> damagedBooks =
      provider.books.where((Book book) => book.damagedCopies > 0 || book.lostCopies > 0).toList();

  final Map<String, int> monthlyStats = provider.monthlyIssueStats(monthCount: 6);
  final int maxMonthlyCount = monthlyStats.values.isEmpty
    ? 1
    : monthlyStats.values.reduce((int a, int b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Analytics & Reports',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 1),
                      initialDate: _from ?? now,
                    );
                    if (picked != null) {
                      setState(() {
                        _from = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: Text(_from == null ? 'From Date' : '${_from!.year}-${_from!.month}-${_from!.day}'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 1),
                      initialDate: _to ?? now,
                    );
                    if (picked != null) {
                      setState(() {
                        _to = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.event_available),
                  label: Text(_to == null ? 'To Date' : '${_to!.year}-${_to!.month}-${_to!.day}'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _from = null;
                      _to = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filter'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Collection Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Total books issued: ${scoped.length}'),
                Text('Active issues: $activeIssues'),
                Text('Completed returns: $completed'),
                Text('Overdue now: $overdue'),
                Text('Due today: ${provider.dueTodayCount}'),
                Text('Due within 3 days: ${provider.dueSoonCount}'),
                Text('Reservations in queue: ${provider.totalReservations}'),
                Text('Acquisition spend: Rs ${provider.acquisitionSpend.toStringAsFixed(2)}'),
                Text('Registered vendors: ${provider.vendorCount}'),
                Text('Tracked copies: ${provider.totalCopiesTracked} | Issued copies: ${provider.issuedCopiesTracked}'),
                Text('Pending penalty approvals: ${provider.pendingPenaltyApprovals}'),
                Text('Damaged copies: ${provider.damagedCopiesCount} | Lost copies: ${provider.lostCopiesCount}'),
                const SizedBox(height: 6),
                Text('Fine collected: Rs ${fineCollected.toStringAsFixed(2)}'),
                Text('Fine outstanding: Rs ${fineOutstanding.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Export scoped report as CSV or PDF.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pw.Document doc = pw.Document();
                    doc.addPage(
                      pw.MultiPage(
                        build: (pw.Context context) => <pw.Widget>[
                          pw.Text('Library Management Report', style: pw.TextStyle(fontSize: 18)),
                          pw.SizedBox(height: 8),
                          pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
                          pw.Text('Records in range: ${scoped.length}'),
                          pw.Text('Active: $activeIssues | Completed: $completed | Overdue: $overdue'),
                          pw.Text('Fine collected: Rs ${fineCollected.toStringAsFixed(2)}'),
                          pw.Text('Fine outstanding: Rs ${fineOutstanding.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                    await Printing.sharePdf(bytes: await doc.save(), filename: 'lms_report_filtered.pdf');
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share PDF'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final StringBuffer csv = StringBuffer();
                    csv.writeln('recordId,book,member,issuedOn,dueOn,returnedOn,finePaid');
                    for (final BorrowRecord record in scoped) {
                      final Book? book = provider.getBookById(record.bookId);
                      final Member? member = provider.getMemberById(record.memberId);
                      csv.writeln(
                        '"${record.id}","${book?.title ?? 'Unknown'}","${member?.name ?? 'Unknown'}","${record.issuedOn.toIso8601String()}","${record.dueOn.toIso8601String()}","${record.returnedOn?.toIso8601String() ?? ''}","${record.finePaid.toStringAsFixed(2)}"',
                      );
                    }
                    await Clipboard.setData(ClipboardData(text: csv.toString()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scoped CSV copied to clipboard.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Copy Scoped CSV'),
                ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final String csv = provider.exportRecordsCsv();
                      await Clipboard.setData(ClipboardData(text: csv));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Full circulation CSV copied to clipboard.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Full CSV'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Monthly Issue Trend (6 Months)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...monthlyStats.entries.map((MapEntry<String, int> entry) {
                    final double ratio = maxMonthlyCount == 0
                        ? 0
                        : entry.value / maxMonthlyCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 72,
                            child: Text(entry.key, style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            child: Stack(
                              children: <Widget>[
                                Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Top Books (Filtered)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (topBooks.isEmpty)
                  const Text('No issue activity in selected range.')
                else
                  ...topBooks.take(5).map(
                    (MapEntry<Book, int> entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(entry.key.title)),
                          Text('${entry.value} issues'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Inventory Condition', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (damagedBooks.isEmpty)
                  const Text('No damaged or lost stock reported.')
                else
                  ...damagedBooks.map(
                    (Book book) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${book.title} - Damaged: ${book.damagedCopies}, Lost: ${book.lostCopies}, Reorder Level: ${book.reorderLevel}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Top Members (Filtered)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (topMembers.isEmpty)
                  const Text('No borrowing activity in selected range.')
                else
                  ...topMembers.take(5).map(
                    (MapEntry<Member, int> entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(entry.key.name)),
                          Text('${entry.value} borrows'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Low Stock Alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (lowStock.isEmpty)
                  const Text('No low stock titles right now.')
                else
                  ...lowStock.map(
                    (Book book) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${book.title} - ${book.availableCopies}/${book.totalCopies} copies left'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
