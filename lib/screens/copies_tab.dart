import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/book_copy.dart';
import '../providers/library_provider.dart';

class CopiesTab extends StatefulWidget {
  const CopiesTab({super.key});

  @override
  State<CopiesTab> createState() => _CopiesTabState();
}

class _CopiesTabState extends State<CopiesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    List<BookCopy> copies = provider.searchCopies(_searchController.text);

    if (_statusFilter != 'all') {
      copies = copies.where((BookCopy copy) => copy.status.key == _statusFilter).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Copy Inventory', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final String csv = provider.exportCopiesCsv();
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copy inventory CSV copied to clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy CSV'),
              ),
              const SizedBox(width: 8),
              Text('Tracked: ${provider.totalCopiesTracked}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search accession, branch, rack, status',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'all', child: Text('All')),
                    DropdownMenuItem<String>(value: 'available', child: Text('Available')),
                    DropdownMenuItem<String>(value: 'issued', child: Text('Issued')),
                    DropdownMenuItem<String>(value: 'damaged', child: Text('Damaged')),
                    DropdownMenuItem<String>(value: 'lost', child: Text('Lost')),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _statusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Copy Status Snapshot'),
              subtitle: Text(
                'Issued: ${provider.issuedCopiesTracked} | '
                'Damaged: ${provider.damagedCopiesCount} | Lost: ${provider.lostCopiesCount}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: copies.isEmpty
                ? const Center(child: Text('No copies found for current filters.'))
                : ListView.builder(
                    itemCount: copies.length,
                    itemBuilder: (BuildContext context, int index) {
                      final BookCopy copy = copies[index];
                      final Book? book = provider.getBookById(copy.bookId);

                      return Card(
                        child: ListTile(
                          title: Text('${copy.accessionNumber} • ${book?.title ?? 'Unknown'}'),
                          subtitle: Text(
                            'Branch: ${copy.branch.isEmpty ? '-' : copy.branch} | '
                            'Rack: ${copy.rack.isEmpty ? '-' : copy.rack}\n'
                            'Status: ${copy.status.key.toUpperCase()}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (String value) {
                              if (value == 'transfer') {
                                _showTransferDialog(context, provider, copy);
                                return;
                              }
                              if (value == 'available') {
                                _changeStatus(context, provider, copy, CopyStatus.available);
                                return;
                              }
                              if (value == 'damaged') {
                                _changeStatus(context, provider, copy, CopyStatus.damaged);
                                return;
                              }
                              if (value == 'lost') {
                                _changeStatus(context, provider, copy, CopyStatus.lost);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'transfer',
                                child: Text('Transfer Branch/Rack'),
                              ),
                              if (copy.status != CopyStatus.issued)
                                const PopupMenuItem<String>(
                                  value: 'available',
                                  child: Text('Mark Available'),
                                ),
                              if (copy.status == CopyStatus.available)
                                const PopupMenuItem<String>(
                                  value: 'damaged',
                                  child: Text('Mark Damaged'),
                                ),
                              if (copy.status == CopyStatus.available)
                                const PopupMenuItem<String>(
                                  value: 'lost',
                                  child: Text('Mark Lost'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _changeStatus(
    BuildContext context,
    LibraryProvider provider,
    BookCopy copy,
    CopyStatus status,
  ) {
    final bool updated = provider.updateCopyStatus(copy.id, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? 'Copy status updated.' : 'Unable to update copy status.')),
    );
  }

  Future<void> _showTransferDialog(
    BuildContext context,
    LibraryProvider provider,
    BookCopy copy,
  ) async {
    final TextEditingController branchController = TextEditingController(text: copy.branch);
    final TextEditingController rackController = TextEditingController(text: copy.rack);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Transfer Copy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: branchController,
                decoration: const InputDecoration(labelText: 'Branch'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rackController,
                decoration: const InputDecoration(labelText: 'Rack'),
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
                final bool ok = provider.transferCopy(
                  copy.id,
                  branch: branchController.text,
                  rack: rackController.text,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Copy transferred.' : 'Unable to transfer copy.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
