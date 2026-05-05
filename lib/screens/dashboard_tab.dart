import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/animated_gradient_panel.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final List<Widget> content = <Widget>[
      Text(
        'Overview',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      StatCard(
        title: 'Total Titles',
        value: provider.totalTitles.toString(),
        icon: Icons.library_books,
        color: const Color(0xFF0A9396),
      ),
      StatCard(
        title: 'Total Members',
        value: provider.totalMembers.toString(),
        icon: Icons.people,
        color: const Color(0xFF005F73),
      ),
      StatCard(
        title: 'Books Issued',
        value: provider.borrowedCount.toString(),
        icon: Icons.swap_horiz,
        color: const Color(0xFFCA6702),
      ),
      StatCard(
        title: 'Overdue Records',
        value: provider.overdueCount.toString(),
        icon: Icons.warning_amber,
        color: const Color(0xFFAE2012),
      ),
      StatCard(
        title: 'Due Today',
        value: provider.dueTodayCount.toString(),
        icon: Icons.today,
        color: const Color(0xFF9C6644),
      ),
      StatCard(
        title: 'Due Soon (3 Days)',
        value: provider.dueSoonCount.toString(),
        icon: Icons.schedule,
        color: const Color(0xFF4D908E),
      ),
      StatCard(
        title: 'Available Copies',
        value: provider.availableCopiesCount.toString(),
        icon: Icons.inventory_2,
        color: const Color(0xFF2A9D8F),
      ),
      StatCard(
        title: 'Fine Collected',
        value: 'Rs ${provider.totalFineCollected.toStringAsFixed(2)}',
        icon: Icons.payments,
        color: const Color(0xFF3A5A40),
      ),
      StatCard(
        title: 'Outstanding Fine',
        value: 'Rs ${provider.totalFineOutstanding.toStringAsFixed(2)}',
        icon: Icons.request_page,
        color: const Color(0xFFB5651D),
      ),
      StatCard(
        title: 'Library Branches',
        value: provider.branchCount.toString(),
        icon: Icons.apartment,
        color: const Color(0xFF264653),
      ),
      StatCard(
        title: 'Book Categories',
        value: provider.categoryCount.toString(),
        icon: Icons.category,
        color: const Color(0xFF577590),
      ),
      StatCard(
        title: 'Inventory Value',
        value: 'Rs ${provider.totalInventoryValue.toStringAsFixed(0)}',
        icon: Icons.currency_rupee,
        color: const Color(0xFF6A994E),
      ),
      StatCard(
        title: 'Expired Members',
        value: provider.expiredMembershipCount.toString(),
        icon: Icons.person_off,
        color: const Color(0xFFBC4749),
      ),
      StatCard(
        title: 'Acquisition Spend',
        value: 'Rs ${provider.acquisitionSpend.toStringAsFixed(0)}',
        icon: Icons.shopping_cart,
        color: const Color(0xFF7F5539),
      ),
      StatCard(
        title: 'Registered Vendors',
        value: provider.vendorCount.toString(),
        icon: Icons.store,
        color: const Color(0xFF386641),
      ),
      StatCard(
        title: 'Tracked Copies',
        value: provider.totalCopiesTracked.toString(),
        icon: Icons.qr_code,
        color: const Color(0xFF1D3557),
      ),
      StatCard(
        title: 'Penalty Approvals',
        value: provider.pendingPenaltyApprovals.toString(),
        icon: Icons.approval,
        color: const Color(0xFF6D597A),
      ),
      StatCard(
        title: 'Damaged Copies',
        value: provider.damagedCopiesCount.toString(),
        icon: Icons.build_circle,
        color: const Color(0xFFE76F51),
      ),
      StatCard(
        title: 'Lost Copies',
        value: provider.lostCopiesCount.toString(),
        icon: Icons.remove_circle,
        color: const Color(0xFF9B2226),
      ),
      AnimatedGradientPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Current Rules',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Default borrow period: ${provider.defaultBorrowDays} days'),
            Text('Fine rate: Rs ${provider.finePerDay.toStringAsFixed(2)} per day'),
            Text('Max books/member: ${provider.maxBooksPerMember}'),
            Text('Max renewals/issue: ${provider.maxRenewals}'),
            Text(
              'Issue block on outstanding: ${provider.blockIssueOnOutstandingBalance ? 'Enabled' : 'Disabled'}',
            ),
            Text(
              'Max outstanding allowed for issue: Rs ${provider.maxOutstandingBalanceForIssue.toStringAsFixed(2)}',
            ),
            Text('Total reservations: ${provider.totalReservations}'),
            Text('Active memberships: ${provider.activeMembershipCount}'),
          ],
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: content
          .asMap()
          .entries
          .map((MapEntry<int, Widget> entry) => StaggeredReveal(index: entry.key, child: entry.value))
          .toList(),
    );
  }
}
