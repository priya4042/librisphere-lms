import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../providers/library_provider.dart';
import '../widgets/interactive_card.dart';
import '../widgets/luxury_empty_state.dart';
import '../widgets/tab_header.dart';

class MembersTab extends StatefulWidget {
  const MembersTab({super.key});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final List<Member> members = provider.searchMembers(_searchController.text);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TabHeader(
            title: 'Members',
            icon: Icons.people_outline,
            subtitle: 'Directory, membership health, and activity overview',
            trailing: Text(
              '${members.length} records',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search name, email, phone, ID, department, type',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () async {
                  final String csv = provider.exportLedgerCsv();
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Member ledger CSV copied to clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Ledger CSV'),
              ),
              OutlinedButton.icon(
                onPressed: provider.canManageMembers
                    ? () => _showMemberImportDialog(context, provider)
                    : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV'),
              ),
              FilledButton.icon(
                onPressed: provider.canManageMembers
                    ? () => _showMemberDialog(context, provider)
                    : null,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Member'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: members.isEmpty
                ? const LuxuryEmptyState(
                    title: 'No Members Yet',
                    message: 'Add your first member record to start circulation tracking.',
                    icon: Icons.people_outline,
                  )
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Member member = members[index];
                      final int activeCount = provider.activeIssuedCountForMember(member.id);
                      final int totalCount = provider.totalBorrowCountForMember(member.id);
                      return InteractiveCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name.characters.first.toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            '${member.membershipId.isEmpty ? 'No ID' : member.membershipId} | ${member.membershipType} | ${member.status}\n'
                            '${member.email} | ${member.phone}\n'
                            'Dept: ${member.department.isEmpty ? '-' : member.department} | Active: $activeCount | Total borrows: $totalCount | Expiry: ${member.expiryDate == null ? '-' : DateFormat('dd MMM yyyy').format(member.expiryDate!)}\n'
                            'Max Books Override: ${member.maxBooksOverride?.toString() ?? '-'} | Notes: ${member.notes.isEmpty ? '-' : member.notes}',
                          ),
                          isThreeLine: false,
                          trailing: Wrap(
                            spacing: 8,
                            children: <Widget>[
                              IconButton(
                                onPressed: provider.canManageMembers
                                    ? () =>
                                        _showMemberDialog(context, provider, member: member)
                                    : null,
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: provider.canManageMembers
                                    ? () {
                                  final bool success = provider.deleteMember(member.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Member deleted.'
                                            : 'Cannot delete member with active issued books.',
                                      ),
                                    ),
                                  );
                                }
                                    : null,
                                icon: const Icon(Icons.delete_outline),
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

  Future<void> _showMemberImportDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    final TextEditingController csvController = TextEditingController();
    bool updateExisting = true;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Import Members From CSV'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Required headers: name,email,phone\n'
                        'Optional: membershipId,membershipType,department,address,status,expiryDate',
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: updateExisting,
                        onChanged: (bool? value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            updateExisting = value;
                          });
                        },
                        title: const Text('Update existing members by email/membershipId'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: csvController,
                        minLines: 8,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          hintText: 'Paste CSV data here',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String message = provider.importMembersCsv(
                      csvController.text,
                      updateExisting: updateExisting,
                    );
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showMemberDialog(
    BuildContext context,
    LibraryProvider provider, {
    Member? member,
  }) async {
    final TextEditingController nameController =
        TextEditingController(text: member?.name ?? '');
    final TextEditingController emailController =
        TextEditingController(text: member?.email ?? '');
    final TextEditingController phoneController =
        TextEditingController(text: member?.phone ?? '');
    final TextEditingController membershipIdController =
      TextEditingController(text: member?.membershipId ?? '');
    final TextEditingController membershipTypeController =
      TextEditingController(text: member?.membershipType ?? 'General');
    final TextEditingController departmentController =
      TextEditingController(text: member?.department ?? '');
    final TextEditingController addressController =
      TextEditingController(text: member?.address ?? '');
    final TextEditingController statusController =
      TextEditingController(text: member?.status ?? 'Active');
    final TextEditingController expiryController = TextEditingController(
      text: member?.expiryDate == null ? '' : DateFormat('yyyy-MM-dd').format(member!.expiryDate!),
    );
    final TextEditingController notesController = TextEditingController(
      text: member?.notes ?? '',
    );
    final TextEditingController maxOverrideController = TextEditingController(
      text: member?.maxBooksOverride?.toString() ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(member == null ? 'Add Member' : 'Edit Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: membershipIdController,
                  decoration: const InputDecoration(labelText: 'Membership ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: membershipTypeController,
                  decoration: const InputDecoration(labelText: 'Membership Type'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: statusController,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(labelText: 'Expiry Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxOverrideController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Books Override (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Member Notes'),
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
                final String name = nameController.text.trim();
                final String email = emailController.text.trim();
                final String phone = phoneController.text.trim();
                final DateTime? expiryDate = expiryController.text.trim().isEmpty
                  ? null
                  : DateTime.tryParse(expiryController.text.trim());
                final int? maxBooksOverride = maxOverrideController.text.trim().isEmpty
                    ? null
                    : int.tryParse(maxOverrideController.text.trim());

                if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter all member details.')),
                  );
                  return;
                }

                if (member == null) {
                  provider.addMember(
                    name: name,
                    email: email,
                    phone: phone,
                    membershipId: membershipIdController.text.trim(),
                    membershipType: membershipTypeController.text.trim(),
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                    status: statusController.text.trim(),
                    expiryDate: expiryDate,
                    notes: notesController.text.trim(),
                    maxBooksOverride: maxBooksOverride,
                  );
                } else {
                  provider.updateMember(
                    member.id,
                    name: name,
                    email: email,
                    phone: phone,
                    membershipId: membershipIdController.text.trim(),
                    membershipType: membershipTypeController.text.trim(),
                    department: departmentController.text.trim(),
                    address: addressController.text.trim(),
                    status: statusController.text.trim(),
                    expiryDate: expiryDate,
                    notes: notesController.text.trim(),
                    maxBooksOverride: maxBooksOverride,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: Text(member == null ? 'Create' : 'Update'),
            ),
          ],
        );
      },
    );
  }
}
