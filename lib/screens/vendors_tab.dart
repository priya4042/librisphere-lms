import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/vendor.dart';
import '../providers/library_provider.dart';

class VendorsTab extends StatefulWidget {
  const VendorsTab({super.key});

  @override
  State<VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<VendorsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final List<Vendor> vendors = provider.searchVendors(_searchController.text);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Vendors', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () async {
                  final String csv = provider.exportVendorsCsv();
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vendor CSV copied to clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy CSV'),
              ),
              OutlinedButton.icon(
                onPressed: provider.canManageBooks
                    ? () => _showVendorImportDialog(context, provider)
                    : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV'),
              ),
              FilledButton.icon(
                onPressed: provider.canManageBooks
                    ? () => _showVendorDialog(context, provider)
                    : null,
                icon: const Icon(Icons.add_business),
                label: const Text('Add Vendor'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search vendor, contact, phone, email',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Vendor Registry'),
              subtitle: Text('Total vendors: ${provider.vendorCount}'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: vendors.isEmpty
                ? const Center(child: Text('No vendors found.'))
                : ListView.builder(
                    itemCount: vendors.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Vendor vendor = vendors[index];
                      return Card(
                        child: ListTile(
                          title: Text(vendor.name),
                          subtitle: Text(
                            '${vendor.contactPerson.isEmpty ? '-' : vendor.contactPerson} | '
                            '${vendor.phone.isEmpty ? '-' : vendor.phone}\n'
                            '${vendor.email.isEmpty ? '-' : vendor.email} | '
                            'Rating: ${vendor.rating}/5',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _showVendorDialog(context, provider, vendor: vendor);
                                return;
                              }
                              final bool deleted = provider.deleteVendor(vendor.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    deleted
                                        ? 'Vendor deleted.'
                                        : 'Cannot delete vendor linked with acquisitions.',
                                  ),
                                ),
                              );
                            },
                            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
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

  Future<void> _showVendorImportDialog(
    BuildContext context,
    LibraryProvider provider,
  ) async {
    final TextEditingController csvController = TextEditingController();
    bool updateExisting = true;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Text('Import Vendors From CSV'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Required header: name\n'
                        'Optional: contactPerson,email,phone,address,gstNumber,paymentTerms,rating',
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
                        title: const Text('Update existing vendors by name'),
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
                    final String message = provider.importVendorsCsv(
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

  Future<void> _showVendorDialog(
    BuildContext context,
    LibraryProvider provider, {
    Vendor? vendor,
  }) async {
    final TextEditingController nameController = TextEditingController(text: vendor?.name ?? '');
    final TextEditingController contactController = TextEditingController(
      text: vendor?.contactPerson ?? '',
    );
    final TextEditingController emailController = TextEditingController(text: vendor?.email ?? '');
    final TextEditingController phoneController = TextEditingController(text: vendor?.phone ?? '');
    final TextEditingController addressController = TextEditingController(
      text: vendor?.address ?? '',
    );
    final TextEditingController gstController = TextEditingController(text: vendor?.gstNumber ?? '');
    final TextEditingController paymentTermsController = TextEditingController(
      text: vendor?.paymentTerms ?? '',
    );
    int rating = vendor?.rating ?? 0;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: Text(vendor == null ? 'Add Vendor' : 'Edit Vendor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Vendor Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(labelText: 'Contact Person'),
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
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: gstController,
                      decoration: const InputDecoration(labelText: 'GST Number'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: paymentTermsController,
                      decoration: const InputDecoration(labelText: 'Payment Terms'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: rating,
                      decoration: const InputDecoration(labelText: 'Rating'),
                      items: List<DropdownMenuItem<int>>.generate(
                        6,
                        (int i) => DropdownMenuItem<int>(value: i, child: Text('$i/5')),
                      ),
                      onChanged: (int? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          rating = value;
                        });
                      },
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
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vendor name is required.')),
                      );
                      return;
                    }

                    if (vendor == null) {
                      provider.addVendor(
                        name: nameController.text,
                        contactPerson: contactController.text,
                        email: emailController.text,
                        phone: phoneController.text,
                        address: addressController.text,
                        gstNumber: gstController.text,
                        paymentTerms: paymentTermsController.text,
                        rating: rating,
                      );
                    } else {
                      provider.updateVendor(
                        vendor.id,
                        name: nameController.text,
                        contactPerson: contactController.text,
                        email: emailController.text,
                        phone: phoneController.text,
                        address: addressController.text,
                        gstNumber: gstController.text,
                        paymentTerms: paymentTermsController.text,
                        rating: rating,
                      );
                    }
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
