import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/borrow_record.dart';
import '../models/member.dart';
import '../providers/library_provider.dart';
import '../widgets/tab_header.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final DateFormat fmt = DateFormat('dd MMM yyyy');

    final List<BorrowRecord> overdueRecords = provider.activeBorrowRecords
        .where((BorrowRecord r) => r.isOverdue)
        .toList()
      ..sort((BorrowRecord a, BorrowRecord b) => a.dueOn.compareTo(b.dueOn));

    final List<BorrowRecord> dueTodayRecords = provider.activeBorrowRecords.where(
      (BorrowRecord r) {
        final DateTime now = DateTime.now();
        return r.dueOn.year == now.year &&
            r.dueOn.month == now.month &&
            r.dueOn.day == now.day;
      },
    ).toList();

    final List<BorrowRecord> dueSoonRecords = provider.dueSoonRecords();

    final List<Book> lowStockBooks = provider.lowStockBooks(threshold: 1);

    final int pendingApprovals = provider.pendingPenaltyApprovals;

    final List<Member> expiredMembers = provider.members
        .where((Member m) {
          if (m.expiryDate == null) return false;
          return m.expiryDate!.isBefore(DateTime.now());
        })
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TabHeader(
          title: 'Notifications',
          icon: Icons.notifications_active_outlined,
          subtitle: 'Live alerts for circulation, stock, and policy actions',
          trailing: Text('Alerts: ${overdueRecords.length + dueSoonRecords.length + pendingApprovals}'),
        ),
        const SizedBox(height: 12),

        // ── Overdue ──────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.warning_amber,
          label: 'Overdue (${overdueRecords.length})',
          color: const Color(0xFFAE2012),
        ),
        if (overdueRecords.isEmpty)
          const _EmptyNote(text: 'No overdue books — great!')
        else
          ...overdueRecords.take(20).map((BorrowRecord record) {
            final Book? book = provider.getBookById(record.bookId);
            final Member? member = provider.getMemberById(record.memberId);
            final int days = DateTime.now().difference(record.dueOn).inDays;
            final double fine = provider.pendingFineForRecord(record);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFAE2012),
                  child: Text(
                    '$days',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(book?.title ?? 'Unknown Book'),
                subtitle: Text(
                  '${member?.name ?? 'Unknown'} · Due ${fmt.format(record.dueOn)} · Fine Rs ${fine.toStringAsFixed(2)}',
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // ── Due Today ────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.today,
          label: 'Due Today (${dueTodayRecords.length})',
          color: const Color(0xFF9C6644),
        ),
        if (dueTodayRecords.isEmpty)
          const _EmptyNote(text: 'No returns due today.')
        else
          ...dueTodayRecords.map((BorrowRecord record) {
            final Book? book = provider.getBookById(record.bookId);
            final Member? member = provider.getMemberById(record.memberId);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF9C6644),
                  child: Icon(Icons.event, color: Colors.white, size: 18),
                ),
                title: Text(book?.title ?? 'Unknown Book'),
                subtitle: Text(member?.name ?? 'Unknown Member'),
              ),
            );
          }),

        const SizedBox(height: 16),

        // ── Due Soon ─────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.schedule,
          label: 'Due in 3 Days (${dueSoonRecords.length})',
          color: const Color(0xFF4D908E),
        ),
        if (dueSoonRecords.isEmpty)
          const _EmptyNote(text: 'No books due in the next 3 days.')
        else
          ...dueSoonRecords.map((BorrowRecord record) {
            final Book? book = provider.getBookById(record.bookId);
            final Member? member = provider.getMemberById(record.memberId);
            final int daysLeft = record.dueOn.difference(DateTime.now()).inDays;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4D908E),
                  child: Text(
                    '+$daysLeft',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(book?.title ?? 'Unknown Book'),
                subtitle: Text(
                  '${member?.name ?? 'Unknown'} · Due ${fmt.format(record.dueOn)}',
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // ── Low Stock ────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.inventory_2,
          label: 'Low Stock / Reorder (${lowStockBooks.length})',
          color: const Color(0xFFCA6702),
        ),
        if (lowStockBooks.isEmpty)
          const _EmptyNote(text: 'No books below reorder threshold.')
        else
          ...lowStockBooks.take(20).map((Book book) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFCA6702),
                  child: Icon(Icons.inventory_2, color: Colors.white, size: 18),
                ),
                title: Text(book.title),
                subtitle: Text(
                  '${book.availableCopies} available / ${book.totalCopies} total · Reorder ≤ ${book.reorderLevel}',
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // ── Pending Approvals ────────────────────────────────────────
        _SectionHeader(
          icon: Icons.approval,
          label: 'Pending Penalty Approvals ($pendingApprovals)',
          color: const Color(0xFF6D597A),
        ),
        if (pendingApprovals == 0)
          const _EmptyNote(text: 'No pending penalty approvals.')
        else
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF6D597A),
                child: Icon(Icons.approval, color: Colors.white, size: 18),
              ),
              title: Text('$pendingApprovals penalties awaiting approval'),
              subtitle: const Text('Go to Ledger tab to review and approve.'),
            ),
          ),

        const SizedBox(height: 16),

        // ── Expired Members ──────────────────────────────────────────
        _SectionHeader(
          icon: Icons.person_off,
          label: 'Expired Memberships (${expiredMembers.length})',
          color: const Color(0xFFBC4749),
        ),
        if (expiredMembers.isEmpty)
          const _EmptyNote(text: 'No expired memberships.')
        else
          ...expiredMembers.take(20).map((Member m) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFBC4749),
                  child: Icon(Icons.person_off, color: Colors.white, size: 18),
                ),
                title: Text(m.name),
                subtitle: Text(
                  'Expired: ${fmt.format(m.expiryDate!)} · ${m.membershipType}',
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}
