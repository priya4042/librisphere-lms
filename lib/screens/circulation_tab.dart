import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/book_copy.dart';
import '../models/borrow_record.dart';
import '../models/member.dart';
import '../providers/library_provider.dart';
import '../widgets/luxury_empty_state.dart';
import '../widgets/tab_header.dart';

enum RecordFilter { active, overdue, returned, all }

class CirculationTab extends StatefulWidget {
  const CirculationTab({super.key});

  @override
  State<CirculationTab> createState() => _CirculationTabState();
}

class _CirculationTabState extends State<CirculationTab> {
  RecordFilter _filter = RecordFilter.active;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _scanController = TextEditingController();
  final Set<String> _selectedRecordIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final bool includeHistory = _filter == RecordFilter.all || _filter == RecordFilter.returned;

    List<BorrowRecord> records = provider.searchRecords(
      _searchController.text,
      includeHistory: includeHistory,
    );

    records = records.where((BorrowRecord record) {
      switch (_filter) {
        case RecordFilter.active:
          return !record.isReturned;
        case RecordFilter.overdue:
          return !record.isReturned && record.isOverdue;
        case RecordFilter.returned:
          return record.isReturned;
        case RecordFilter.all:
          return true;
      }
    }).toList();

    records.sort(
      (BorrowRecord a, BorrowRecord b) => b.issuedOn.compareTo(a.issuedOn),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TabHeader(
            title: 'Circulation Desk',
            icon: Icons.swap_horiz,
            subtitle: 'Issue, return, renew, and monitor queue operations',
            trailing: Text(
              '${records.length} records',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Quick Scan / Accession Return Panel
          if (provider.canManageCirculation)
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.qr_code_scanner, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _scanController,
                        decoration: const InputDecoration(
                          hintText: 'Scan / enter accession number for quick return',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (String value) {
                          if (value.trim().isEmpty) return;
                          final LibraryProvider p = context.read<LibraryProvider>();
                          final String result = p.quickReturnByAccession(value.trim());
                          _scanController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result)),
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final String val = _scanController.text.trim();
                        if (val.isEmpty) return;
                        final LibraryProvider p = context.read<LibraryProvider>();
                        final String result = p.quickReturnByAccession(val);
                        _scanController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result)),
                        );
                      },
                      child: const Text('Return'),
                    ),
                  ],
                ),
              ),
            ),
          // Batch return bar (visible when selections exist)
          if (_selectedRecordIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Text('${_selectedRecordIds.length} selected'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedRecordIds.clear()),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final LibraryProvider p = context.read<LibraryProvider>();
                      final String msg = p.batchReturnBooks(_selectedRecordIds.toList());
                      setState(() => _selectedRecordIds.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    },
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('Return Selected'),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by member, title, or ISBN',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: provider.canManageCirculation
                    ? () => _showIssueDialog(context, provider)
                    : null,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Issue'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: provider.canManageCirculation
                    ? () => _showReservationDialog(context, provider)
                    : null,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Reserve'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: provider.canManageCirculation
                    ? () => _showWaitlistDialog(context, provider)
                    : null,
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Waitlists'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip(RecordFilter.active, 'Active'),
                const SizedBox(width: 8),
                _filterChip(RecordFilter.overdue, 'Overdue'),
                const SizedBox(width: 8),
                _filterChip(RecordFilter.returned, 'Returned'),
                const SizedBox(width: 8),
                _filterChip(RecordFilter.all, 'All'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: records.isEmpty
                ? const LuxuryEmptyState(
                    title: 'No Circulation Records',
                    message: 'Issue a book or clear filters to view circulation activity.',
                    icon: Icons.swap_horiz,
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (BuildContext context, int index) {
                      final BorrowRecord record = records[index];
                      final bool isSelected = _selectedRecordIds.contains(record.id);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (!record.isReturned && provider.canManageCirculation)
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedRecordIds.add(record.id);
                                  } else {
                                    _selectedRecordIds.remove(record.id);
                                  }
                                });
                              },
                            )
                          else
                            const SizedBox(width: 48),
                          Expanded(
                            child: _IssueRecordTile(
                              record: record,
                              provider: provider,
                              onReturn: () => _showReturnDialog(context, provider, record),
                              onCollectFine: () =>
                                  _showCollectFineDialog(context, provider, record),
                              onRenew: () => _showRenewDialog(context, provider, record),
                              onReceipt: () => _shareFineReceipt(context, provider, record),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReservationDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    String? selectedBookId;
    String? selectedMemberId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reserve Book'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedBookId,
                    items: provider.books
                        .map(
                          (Book book) => DropdownMenuItem<String>(
                            value: book.id,
                            child: Text(
                              '${book.title} (${book.availableCopies}/${book.totalCopies}) - waitlist ${provider.waitlistCountForBook(book.id)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedBookId = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Book'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedMemberId,
                    items: provider.members
                        .map(
                          (Member member) => DropdownMenuItem<String>(
                            value: member.id,
                            child: Text(member.name),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedMemberId = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Member'),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedBookId == null || selectedMemberId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select both book and member.')),
                  );
                  return;
                }

                final String message = provider.placeReservation(
                  bookId: selectedBookId!,
                  memberId: selectedMemberId!,
                );
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                if (message.toLowerCase().contains('added')) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Reserve'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenewDialog(
    BuildContext context,
    LibraryProvider provider,
    BorrowRecord record,
  ) async {
    final TextEditingController extraDaysController = TextEditingController(text: '7');

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Renew Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Current renewals: ${record.renewCount}/${provider.maxRenewals}'),
              const SizedBox(height: 8),
              TextField(
                controller: extraDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extra Days'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final int? days = int.tryParse(extraDaysController.text.trim());
                if (days == null || days <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid number of days.')),
                  );
                  return;
                }

                final bool ok = provider.renewBorrow(record.id, extraDays: days);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Renewal failed (limit reached or waitlist exists).')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue renewed successfully.')),
                );
              },
              child: const Text('Renew'),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(RecordFilter value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Future<void> _showIssueDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    String? selectedBookId;
    String? selectedMemberId;
    String? selectedCopyId;
    final TextEditingController borrowDaysController =
        TextEditingController(text: provider.defaultBorrowDays.toString());

    final List<Book> availableBooks =
        provider.books.where((Book b) => b.availableCopies > 0).toList();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Issue Book'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedBookId,
                    items: availableBooks
                        .map(
                          (Book book) => DropdownMenuItem<String>(
                            value: book.id,
                            child: Text('${book.title} (${book.availableCopies} left)'),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedBookId = value;
                        selectedCopyId = null;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Book'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedCopyId,
                    items: selectedBookId == null
                        ? const <DropdownMenuItem<String>>[]
                        : provider
                            .copiesForBook(selectedBookId!)
                            .where((copy) => copy.status == CopyStatus.available)
                            .map(
                              (copy) => DropdownMenuItem<String>(
                                value: copy.id,
                                child: Text(
                                  '${copy.accessionNumber} • ${copy.branch.isEmpty ? 'Main' : copy.branch}',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedCopyId = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Specific Copy (Optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedMemberId,
                    items: provider.members
                        .map(
                          (Member member) => DropdownMenuItem<String>(
                            value: member.id,
                            child: Text(member.name),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      setState(() {
                        selectedMemberId = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Select Member'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: borrowDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Borrow Days'),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedBookId == null || selectedMemberId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select both book and member.')),
                  );
                  return;
                }

                final int? borrowDays = int.tryParse(borrowDaysController.text.trim());
                if (borrowDays == null || borrowDays <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Borrow days must be a valid number.')),
                  );
                  return;
                }

                final String message = provider.issueBook(
                  bookId: selectedBookId!,
                  memberId: selectedMemberId!,
                  borrowDays: borrowDays,
                  specificCopyId: selectedCopyId,
                );

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                if (message.toLowerCase().contains('success')) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Issue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReturnDialog(
    BuildContext context,
    LibraryProvider provider,
    BorrowRecord record,
  ) async {
    final double pendingFine = provider.pendingFineForRecord(record);
    final TextEditingController fineController = TextEditingController(
      text: pendingFine.toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Return Book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Pending fine: Rs ${pendingFine.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              TextField(
                controller: fineController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Fine Paid Now',
                  prefixText: 'Rs ',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final double paid = double.tryParse(fineController.text.trim()) ?? 0;
                if (paid < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fine paid cannot be negative.')),
                  );
                  return;
                }

                final bool ok = provider.returnBook(record.id, paidAmount: paid);
                if (ok) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book returned successfully.')),
                  );
                  if (paid > 0) {
                    _shareFineReceipt(context, provider, record);
                  }
                }
              },
              child: const Text('Return'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCollectFineDialog(
    BuildContext context,
    LibraryProvider provider,
    BorrowRecord record,
  ) async {
    final TextEditingController amountController = TextEditingController();
    final double pending = provider.pendingFineForRecord(record);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Collect Fine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Pending fine: Rs ${pending.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final double amount = double.tryParse(amountController.text.trim()) ?? 0;
                final bool ok = provider.collectFine(record.id, amount);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to collect fine with that amount.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fine collected successfully.')),
                );
                _shareFineReceipt(context, provider, record, collectedAmount: amount);
              },
              child: const Text('Collect'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWaitlistDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Manage Waitlists'),
              content: SizedBox(
                width: 540,
                child: provider.totalReservations == 0
                    ? const Text('No reservations in queue.')
                    : ListView(
                        shrinkWrap: true,
                        children: provider.books
                            .where((Book book) => provider.waitlistCountForBook(book.id) > 0)
                            .map((Book book) {
                          final List<Member> queue = provider.waitlistMembersForBook(book.id);
                          return Card(
                            child: ExpansionTile(
                              title: Text(book.title),
                              subtitle: Text('Queue: ${queue.length}'),
                              children: queue
                                  .map(
                                    (Member member) => ListTile(
                                      title: Text(member.name),
                                      subtitle: Text(member.email),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () {
                                          final bool removed = provider.cancelReservation(
                                            bookId: book.id,
                                            memberId: member.id,
                                          );
                                          setState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                removed
                                                    ? 'Reservation removed.'
                                                    : 'Unable to remove reservation.',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareFineReceipt(
    BuildContext context,
    LibraryProvider provider,
    BorrowRecord record, {
    double? collectedAmount,
  }) async {
    final Book? book = provider.getBookById(record.bookId);
    final Member? member = provider.getMemberById(record.memberId);
    final double amount = collectedAmount ?? record.finePaid;
    if (amount <= 0) {
      return;
    }

    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text('Library Fine Receipt', style: pw.TextStyle(fontSize: 22)),
            pw.SizedBox(height: 10),
            pw.Text('Date: ${DateTime.now().toIso8601String()}'),
            pw.Text('Receipt ID: ${record.id}'),
            pw.SizedBox(height: 12),
            pw.Text('Member: ${member?.name ?? 'Unknown'}'),
            pw.Text('Book: ${book?.title ?? 'Unknown'}'),
            pw.Text('Issued On: ${DateFormat('dd MMM yyyy').format(record.issuedOn)}'),
            pw.Text('Due On: ${DateFormat('dd MMM yyyy').format(record.dueOn)}'),
            if (record.returnedOn != null)
              pw.Text('Returned On: ${DateFormat('dd MMM yyyy').format(record.returnedOn!)}'),
            pw.SizedBox(height: 10),
            pw.Text('Total Fine: Rs ${provider.totalFineForRecord(record).toStringAsFixed(2)}'),
            pw.Text('Paid So Far: Rs ${record.finePaid.toStringAsFixed(2)}'),
            pw.Text('Pending: Rs ${provider.pendingFineForRecord(record).toStringAsFixed(2)}'),
            pw.SizedBox(height: 10),
            pw.Text('Collected This Action: Rs ${amount.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'fine_receipt_${record.id}.pdf');
  }
}

class _IssueRecordTile extends StatelessWidget {
  const _IssueRecordTile({
    required this.record,
    required this.provider,
    required this.onReturn,
    required this.onCollectFine,
    required this.onRenew,
    required this.onReceipt,
  });

  final BorrowRecord record;
  final LibraryProvider provider;
  final VoidCallback onReturn;
  final VoidCallback onCollectFine;
  final VoidCallback onRenew;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final Book? book = provider.getBookById(record.bookId);
    final Member? member = provider.getMemberById(record.memberId);
    final double pendingFine = provider.pendingFineForRecord(record);

    return Card(
      child: ListTile(
        title: Text(book?.title ?? 'Unknown Book'),
        subtitle: Text(
          'Member: ${member?.name ?? 'Unknown'}\n'
          'Issued: ${DateFormat('dd MMM yyyy').format(record.issuedOn)}\n'
          'Due: ${DateFormat('dd MMM yyyy').format(record.dueOn)}\n'
          'Renewals: ${record.renewCount}/${provider.maxRenewals}\n'
          'Fine pending: Rs ${pendingFine.toStringAsFixed(2)}'
          '${record.returnedOn != null ? '\nReturned: ${DateFormat('dd MMM yyyy').format(record.returnedOn!)}' : ''}',
        ),
        isThreeLine: true,
        trailing: record.isReturned
            ? Wrap(
                spacing: 6,
                children: <Widget>[
                  const Chip(label: Text('Returned')),
                  if (record.finePaid > 0)
                    TextButton(
                      onPressed: onReceipt,
                      child: const Text('Receipt'),
                    ),
                  if (pendingFine > 0)
                    TextButton(
                      onPressed: onCollectFine,
                      child: const Text('Collect Fine'),
                    ),
                ],
              )
            : Wrap(
                spacing: 6,
                children: <Widget>[
                  if (record.isOverdue)
                    const Chip(
                      label: Text('Overdue'),
                      backgroundColor: Color(0xFFFEE4E2),
                    ),
                  OutlinedButton(
                    onPressed: onRenew,
                    child: const Text('Renew'),
                  ),
                  FilledButton.tonal(
                    onPressed: onReturn,
                    child: const Text('Return'),
                  ),
                ],
              ),
      ),
    );
  }
}
