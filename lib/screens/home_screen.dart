import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'books_tab.dart';
import 'circulation_tab.dart';
import 'dashboard_tab.dart';
import 'members_tab.dart';
import 'reports_tab.dart';
import 'admin_tab.dart';
import 'acquisitions_tab.dart';
import 'vendors_tab.dart';
import 'copies_tab.dart';
import 'ledger_tab.dart';
import 'notifications_tab.dart';
import '../providers/library_provider.dart';
import '../models/user_role.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<String> _titles = <String>[
    'Dashboard',
    'Books',
    'Members',
    'Circulation',
    'Acquisitions',
    'Vendors',
    'Copies',
    'Ledger',
    'Notifications',
    'Reports',
    'Admin',
  ];

  final List<Widget> _tabs = const <Widget>[
    DashboardTab(),
    BooksTab(),
    MembersTab(),
    CirculationTab(),
    AcquisitionsTab(),
    VendorsTab(),
    CopiesTab(),
    LedgerTab(),
    NotificationsTab(),
    ReportsTab(),
    AdminTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('LMS - ${_titles[_selectedIndex]}'),
        actions: <Widget>[
          PopupMenuButton<UserRole>(
            tooltip: 'Switch Role',
            icon: const Icon(Icons.manage_accounts),
            onSelected: (UserRole role) {
              _showRolePinDialog(context, provider, role);
            },
            itemBuilder: (BuildContext context) => UserRole.values
                .map(
                  (UserRole role) => PopupMenuItem<UserRole>(
                    value: role,
                    child: Row(
                      children: <Widget>[
                        if (provider.currentRole == role)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.check, size: 18),
                          ),
                        Text(role.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: provider.canAccessSettings
                ? () => _showSettingsDialog(context, provider)
                : null,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFEAF5FA),
              Color(0xFFF7FAFC),
              Color(0xFFF4F7FB),
            ],
          ),
        ),
        child: provider.isReady
            ? Column(
                children: <Widget>[
                  _KpiStrip(provider: provider),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final Animation<Offset> slide = Tween<Offset>(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _tabs[_selectedIndex],
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Books',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Circulation',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Acquisitions',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Copies',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    final TextEditingController borrowController =
        TextEditingController(text: provider.defaultBorrowDays.toString());
    final TextEditingController fineController =
        TextEditingController(text: provider.finePerDay.toStringAsFixed(2));
    final TextEditingController maxBooksController =
      TextEditingController(text: provider.maxBooksPerMember.toString());
    final TextEditingController maxRenewalsController =
      TextEditingController(text: provider.maxRenewals.toString());
    final TextEditingController outstandingLimitController =
      TextEditingController(text: provider.maxOutstandingBalanceForIssue.toStringAsFixed(2));
    bool blockOnOutstanding = provider.blockIssueOnOutstandingBalance;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('LMS Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: borrowController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default Borrow Days',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fineController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Fine Per Day',
                        prefixText: 'Rs ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxBooksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Books Per Member',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maxRenewalsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Renewals Per Issue',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: blockOnOutstanding,
                      onChanged: (bool value) {
                        setDialogState(() {
                          blockOnOutstanding = value;
                        });
                      },
                      title: const Text('Block Issue on Outstanding Balance'),
                      subtitle: const Text('Prevent new issue when member ledger balance is high.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: outstandingLimitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Max Outstanding Balance for Issue',
                        prefixText: 'Rs ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final String data = provider.exportFullStateJson();
                            await Clipboard.setData(ClipboardData(text: data));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Backup JSON copied to clipboard.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_all),
                          label: const Text('Backup'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showImportDialog(context, provider),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Restore'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showResetDialog(context, provider),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('Reset'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showPinChangeDialog(context, provider),
                          icon: const Icon(Icons.password),
                          label: const Text('Change PIN'),
                        ),
                      ],
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
                    final int? borrowDays = int.tryParse(borrowController.text.trim());
                    final double? fine = double.tryParse(fineController.text.trim());
                    final int? maxBooks = int.tryParse(maxBooksController.text.trim());
                    final int? maxRenewals = int.tryParse(maxRenewalsController.text.trim());
                    final double? outstandingLimit =
                        double.tryParse(outstandingLimitController.text.trim());
                    if (
                        borrowDays == null ||
                        borrowDays <= 0 ||
                        fine == null ||
                        fine < 0 ||
                        maxBooks == null ||
                        maxBooks <= 0 ||
                        maxRenewals == null ||
                        maxRenewals < 0 ||
                        outstandingLimit == null ||
                        outstandingLimit < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid settings values.')),
                      );
                      return;
                    }

                    provider.updateSettings(
                      defaultBorrowDays: borrowDays,
                      finePerDay: fine,
                      maxBooksPerMember: maxBooks,
                      maxRenewals: maxRenewals,
                      blockIssueOnOutstandingBalance: blockOnOutstanding,
                      maxOutstandingBalanceForIssue: outstandingLimit,
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

  Future<void> _showImportDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    final TextEditingController jsonController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore From JSON'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: jsonController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                hintText: 'Paste exported LMS JSON here',
                border: OutlineInputBorder(),
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
                final String message = provider.importFullStateJson(jsonController.text.trim());
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResetDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset LMS Data'),
          content: const Text(
            'This clears all books, members, records, and reservations. Seed data will be restored.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await provider.resetAllData(reseed: true);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('LMS data reset complete.')),
                  );
                }
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRolePinDialog(
    BuildContext context,
    LibraryProvider provider,
    UserRole targetRole,
  ) async {
    final TextEditingController pinController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Switch To ${targetRole.label}'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Admin PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String message = provider.switchRoleSecure(
                  targetRole,
                  pinController.text,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
              },
              child: const Text('Switch'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPinChangeDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    final TextEditingController oldPinController = TextEditingController();
    final TextEditingController newPinController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Change Admin PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: oldPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New PIN'),
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
                final String message = provider.updateAdminPin(
                  oldPin: oldPinController.text,
                  newPin: newPinController.text,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.provider});

  final LibraryProvider provider;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0B7285), Color(0xFF1D4E89)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF0B7285).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Live Library Pulse',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _chip('Issued ${provider.borrowedCount}'),
            const SizedBox(width: 6),
            _chip('Overdue ${provider.overdueCount}'),
            const SizedBox(width: 6),
            _chip('Members ${provider.totalMembers}'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
