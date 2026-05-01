import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/acquisition.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';

class AcquisitionsTab extends StatelessWidget {
  const AcquisitionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Acquisitions', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: provider.canManageBooks
                    ? () => _showAcquisitionDialog(context, provider)
                    : null,
                icon: const Icon(Icons.add_business),
                label: const Text('Add Procurement'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Procurement Spend'),
              subtitle: Text('Total acquisitions: ${provider.acquisitions.length}'),
              trailing: Text('Rs ${provider.acquisitionSpend.toStringAsFixed(0)}'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: provider.acquisitions.isEmpty
                ? const Center(child: Text('No acquisitions recorded yet.'))
                : ListView.builder(
                    itemCount: provider.acquisitions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Acquisition acquisition = provider.acquisitions[index];
                      final Book? book = provider.getBookById(acquisition.bookId);
                      return Card(
                        child: ListTile(
                          title: Text(book?.title ?? 'Unknown Book'),
                          subtitle: Text(
                            '${acquisition.vendor} | ${acquisition.branch.isEmpty ? 'Main' : acquisition.branch}\n'
                            'Qty: ${acquisition.quantity} | Unit: Rs ${acquisition.unitCost.toStringAsFixed(0)} | Invoice: ${acquisition.invoiceNumber.isEmpty ? '-' : acquisition.invoiceNumber}\n'
                            'Date: ${DateFormat('dd MMM yyyy').format(acquisition.acquiredOn)}',
                          ),
                          isThreeLine: true,
                          trailing: Text('Rs ${acquisition.totalCost.toStringAsFixed(0)}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAcquisitionDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    String? selectedBookId;
    final TextEditingController vendorController = TextEditingController();
    final TextEditingController branchController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    final TextEditingController costController = TextEditingController();
    final TextEditingController invoiceController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Procurement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedBookId,
                  items: provider.books
                      .map(
                        (Book book) => DropdownMenuItem<String>(
                          value: book.id,
                          child: Text(book.title),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    selectedBookId = value;
                  },
                  decoration: const InputDecoration(labelText: 'Select Book'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vendorController,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: branchController,
                  decoration: const InputDecoration(labelText: 'Branch'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit Cost'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: invoiceController,
                  decoration: const InputDecoration(labelText: 'Invoice Number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
                final int? quantity = int.tryParse(quantityController.text.trim());
                final double? cost = double.tryParse(costController.text.trim());
                if (selectedBookId == null || vendorController.text.trim().isEmpty || quantity == null || quantity <= 0 || cost == null || cost < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid procurement details.')),
                  );
                  return;
                }

                provider.addAcquisition(
                  bookId: selectedBookId!,
                  vendor: vendorController.text.trim(),
                  branch: branchController.text.trim(),
                  quantity: quantity,
                  unitCost: cost,
                  invoiceNumber: invoiceController.text.trim(),
                  notes: notesController.text.trim(),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
