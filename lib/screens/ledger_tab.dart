import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/member_ledger_entry.dart';
import '../providers/library_provider.dart';

class LedgerTab extends StatefulWidget {
  const LedgerTab({super.key});

  @override
  State<LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<LedgerTab> {
  String? _selectedMemberId;
  bool _pendingOnly = false;

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();

    if (provider.members.isNotEmpty && _selectedMemberId == null) {
      _selectedMemberId = provider.members.first.id;
    }

    final String? memberId = _selectedMemberId;
    List<MemberLedgerEntry> entries = memberId == null
        ? <MemberLedgerEntry>[]
        : provider.ledgerForMember(memberId);

    if (_pendingOnly) {
      entries = entries
          .where((MemberLedgerEntry e) => e.approvalStatus == LedgerApprovalStatus.pending)
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Member Ledger', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  final String csv = provider.exportLedgerCsv(memberId: memberId);
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ledger CSV copied to clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Ledger CSV'),
              ),
              const SizedBox(width: 8),
              Text('Pending approvals: ${provider.pendingPenaltyApprovals}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: memberId,
                  decoration: const InputDecoration(
                    labelText: 'Member',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.members
                      .map(
                        (Member member) => DropdownMenuItem<String>(
                          value: member.id,
                          child: Text(
                            member.membershipId.isEmpty
                                ? member.name
                                : '${member.name} (${member.membershipId})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    setState(() {
                      _selectedMemberId = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                selected: _pendingOnly,
                label: const Text('Pending Only'),
                onSelected: (bool value) {
                  setState(() {
                    _pendingOnly = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Outstanding Balance'),
              subtitle: Text(
                memberId == null
                    ? 'Select member to view balance.'
                    : 'Rs ${provider.memberBalance(memberId).toStringAsFixed(2)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: memberId == null
                    ? null
                    : () => _showEntryDialog(context, provider, memberId),
                icon: const Icon(Icons.add_card),
                label: const Text('Add Entry'),
              ),
              OutlinedButton.icon(
                onPressed: memberId == null
                    ? null
                    : () => _showPenaltyDialog(context, provider, memberId),
                icon: const Icon(Icons.gavel),
                label: const Text('Add Penalty'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No ledger entries for selected member.'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MemberLedgerEntry entry = entries[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${entry.type.key.toUpperCase()} • Rs ${entry.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy, hh:mm a').format(entry.createdOn)}\n'
                            '${entry.description.isEmpty ? '-' : entry.description}\n'
                            'Ref: ${entry.referenceId.isEmpty ? '-' : entry.referenceId} | '
                            'Status: ${entry.approvalStatus.key}',
                          ),
                          isThreeLine: true,
                          trailing: entry.approvalStatus == LedgerApprovalStatus.pending
                              ? FilledButton(
                                  onPressed: provider.canAccessSettings
                                      ? () {
                                          provider.approveLedgerEntry(entry.id);
                                        }
                                      : null,
                                  child: const Text('Approve'),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPenaltyDialog(
    BuildContext context,
    LibraryProvider provider,
    String memberId,
  ) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    bool requiresApproval = true;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Add Penalty'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: requiresApproval,
                      onChanged: (bool? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          requiresApproval = value;
                        });
                      },
                      title: const Text('Require Admin Approval'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final double? amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount.')),
                      );
                      return;
                    }
                    provider.addPenalty(
                      memberId: memberId,
                      amount: amount,
                      description: descriptionController.text.trim(),
                      requiresApproval: requiresApproval,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEntryDialog(
    BuildContext context,
    LibraryProvider provider,
    String memberId,
  ) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController referenceController = TextEditingController();
    LedgerEntryType type = LedgerEntryType.payment;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Add Ledger Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<LedgerEntryType>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const <DropdownMenuItem<LedgerEntryType>>[
                        DropdownMenuItem<LedgerEntryType>(
                          value: LedgerEntryType.payment,
                          child: Text('Payment'),
                        ),
                        DropdownMenuItem<LedgerEntryType>(
                          value: LedgerEntryType.waiver,
                          child: Text('Waiver'),
                        ),
                      ],
                      onChanged: (LedgerEntryType? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          type = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(labelText: 'Reference ID'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final double? amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount.')),
                      );
                      return;
                    }
                    provider.addLedgerEntry(
                      memberId: memberId,
                      type: type,
                      amount: amount,
                      referenceId: referenceController.text.trim(),
                      description: descriptionController.text.trim(),
                      approvalStatus: LedgerApprovalStatus.approved,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
