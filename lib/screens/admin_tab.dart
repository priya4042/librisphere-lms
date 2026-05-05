import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/audit_log.dart';
import '../providers/library_provider.dart';
import '../widgets/luxury_empty_state.dart';
import '../widgets/tab_header.dart';

class AdminTab extends StatefulWidget {
  const AdminTab({super.key});

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'All';
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();

    if (!provider.canViewAudit) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Admin role required to view audit logs.'),
        ),
      );
    }

    List<AuditLog> logs = provider.auditLogs.toList();
    final String q = _searchController.text.trim().toLowerCase();

    if (_roleFilter != 'All') {
      logs = logs.where((AuditLog log) => log.role == _roleFilter).toList();
    }
    if (_from != null) {
      final DateTime from = DateTime(_from!.year, _from!.month, _from!.day);
      logs = logs.where((AuditLog log) => !log.timestamp.isBefore(from)).toList();
    }
    if (_to != null) {
      final DateTime to = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      logs = logs.where((AuditLog log) => !log.timestamp.isAfter(to)).toList();
    }
    if (q.isNotEmpty) {
      logs = logs
          .where(
            (AuditLog log) =>
                log.action.toLowerCase().contains(q) ||
                log.details.toLowerCase().contains(q) ||
                log.role.toLowerCase().contains(q),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TabHeader(
            title: 'Audit Logs',
            icon: Icons.admin_panel_settings_outlined,
            subtitle: 'Administrative traceability and governance events',
            trailing: OutlinedButton.icon(
              onPressed: () async {
                final String csv = provider.exportAuditCsv();
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audit CSV copied to clipboard.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy CSV'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search action/details/role',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  value: _roleFilter,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Role',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'All', child: Text('All')),
                    DropdownMenuItem<String>(value: 'Admin', child: Text('Admin')),
                    DropdownMenuItem<String>(value: 'Librarian', child: Text('Librarian')),
                    DropdownMenuItem<String>(value: 'Guest', child: Text('Guest')),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _roleFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                label: Text(_from == null ? 'From Date' : DateFormat('dd MMM yyyy').format(_from!)),
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
                label: Text(_to == null ? 'To Date' : DateFormat('dd MMM yyyy').format(_to!)),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _from = null;
                    _to = null;
                    _roleFilter = 'All';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: logs.isEmpty
                    ? const LuxuryEmptyState(
                        title: 'No Audit Entries',
                        message: 'No admin activity matches the current filters.',
                        icon: Icons.admin_panel_settings_outlined,
                      )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final AuditLog log = logs[index];
                      return Card(
                        child: ListTile(
                          title: Text(log.action),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp)}\nRole: ${log.role}\n${log.details}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
