import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/library_provider.dart';
import '../widgets/interactive_card.dart';
import '../widgets/luxury_empty_state.dart';
import '../widgets/tab_header.dart';

enum BookSort { title, available, popularity, waitlist }

class BooksTab extends StatefulWidget {
  const BooksTab({super.key});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  final TextEditingController _searchController = TextEditingController();
  BookSort _sort = BookSort.title;
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider provider = context.watch<LibraryProvider>();
    final List<Book> books = provider.searchBooks(_searchController.text).toList();

    if (_lowStockOnly) {
      books.removeWhere((Book book) => book.availableCopies > 1);
    }

    books.sort((Book a, Book b) {
      switch (_sort) {
        case BookSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case BookSort.available:
          return a.availableCopies.compareTo(b.availableCopies);
        case BookSort.popularity:
          return provider
              .totalBorrowCountForBook(b.id)
              .compareTo(provider.totalBorrowCountForBook(a.id));
        case BookSort.waitlist:
          return provider
              .waitlistCountForBook(b.id)
              .compareTo(provider.waitlistCountForBook(a.id));
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TabHeader(
            title: 'Books Catalog',
            icon: Icons.menu_book_outlined,
            subtitle: 'Manage titles, metadata, and inventory quality',
            trailing: Text(
              '${books.length} results',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search title, author, ISBN, category, branch, rack',
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
                  final String csv = provider.exportBooksCsv();
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Books CSV copied to clipboard.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('Books CSV'),
              ),
              OutlinedButton.icon(
                onPressed: provider.canManageBooks
                    ? () => _showBookImportDialog(context, provider)
                    : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import CSV'),
              ),
              FilledButton.icon(
                onPressed: provider.canManageBooks
                    ? () => _showBookDialog(context, provider)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<BookSort>(
                  value: _sort,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<BookSort>>[
                    DropdownMenuItem<BookSort>(
                      value: BookSort.title,
                      child: Text('Title'),
                    ),
                    DropdownMenuItem<BookSort>(
                      value: BookSort.available,
                      child: Text('Available Copies'),
                    ),
                    DropdownMenuItem<BookSort>(
                      value: BookSort.popularity,
                      child: Text('Popularity'),
                    ),
                    DropdownMenuItem<BookSort>(
                      value: BookSort.waitlist,
                      child: Text('Waitlist Size'),
                    ),
                  ],
                  onChanged: (BookSort? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _sort = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Low Stock'),
                selected: _lowStockOnly,
                onSelected: (bool value) {
                  setState(() {
                    _lowStockOnly = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: books.isEmpty
                ? const LuxuryEmptyState(
                    title: 'No Books Found',
                    message: 'Try a different keyword or add a new title to begin.',
                    icon: Icons.menu_book_outlined,
                  )
                : ListView.builder(
                    itemCount: books.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Book book = books[index];
                      final int issuedTimes = provider.totalBorrowCountForBook(book.id);
                      final int waitlistCount = provider.waitlistCountForBook(book.id);
                      return InteractiveCard(
                        child: ListTile(
                          title: Text(book.title),
                          subtitle: Text(
                            '${book.author} | ${book.category.isEmpty ? 'Uncategorized' : book.category}\n'
                            'Branch: ${book.branch.isEmpty ? 'Main' : book.branch} | Rack: ${book.rack.isEmpty ? '-' : book.rack} | ISBN: ${book.isbn}\n'
                            'Available: ${book.availableCopies}/${book.totalCopies} | Damaged: ${book.damagedCopies} | Lost: ${book.lostCopies} | Reorder: ${book.reorderLevel}\n'
                            'Issued: $issuedTimes | Waitlist: $waitlistCount | Rs ${book.unitPrice.toStringAsFixed(0)}\n'
                            'Tags: ${book.tags.isEmpty ? '-' : book.tags.join(', ')}${book.description.isEmpty ? '' : '\n${book.description}'}',
                          ),
                          isThreeLine: false,
                          trailing: Wrap(
                            spacing: 8,
                            children: <Widget>[
                              PopupMenuButton<String>(
                                onSelected: (String value) {
                                  bool success = false;
                                  if (value == 'damaged') {
                                    success = provider.markBookDamaged(book.id);
                                  } else if (value == 'restore') {
                                    success = provider.restoreDamagedBook(book.id);
                                  } else if (value == 'lost') {
                                    success = provider.markBookLost(book.id);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Inventory updated.' : 'Unable to update inventory.',
                                      ),
                                    ),
                                  );
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'damaged',
                                    child: Text('Mark 1 Damaged'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'restore',
                                    child: Text('Restore 1 Damaged'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'lost',
                                    child: Text('Mark 1 Lost'),
                                  ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.inventory_2_outlined),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: provider.canManageBooks
                                    ? () => _showBookDialog(context, provider, book: book)
                                    : null,
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: provider.canManageBooks
                                    ? () {
                                  final bool success = provider.deleteBook(book.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Book deleted.'
                                            : 'Cannot delete a book with active issues.',
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

  Future<void> _showBookImportDialog(
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
              title: const Text('Import Books From CSV'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Required headers: title,author,isbn,totalCopies\n'
                        'Optional: category,branch,rack,publisher,edition,language,publishedYear,unitPrice,reorderLevel',
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
                        title: const Text('Update existing books by ISBN'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: csvController,
                        minLines: 10,
                        maxLines: 16,
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
                    final String message = provider.importBooksCsv(
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

  Future<void> _showBookDialog(
    BuildContext context,
    LibraryProvider provider, {
    Book? book,
  }) async {
    final TextEditingController titleController =
        TextEditingController(text: book?.title ?? '');
    final TextEditingController authorController =
        TextEditingController(text: book?.author ?? '');
    final TextEditingController isbnController =
        TextEditingController(text: book?.isbn ?? '');
    final TextEditingController copiesController = TextEditingController(
      text: (book?.totalCopies ?? 1).toString(),
    );
    final TextEditingController categoryController =
      TextEditingController(text: book?.category ?? '');
    final TextEditingController branchController =
      TextEditingController(text: book?.branch ?? '');
    final TextEditingController rackController =
      TextEditingController(text: book?.rack ?? '');
    final TextEditingController publisherController =
      TextEditingController(text: book?.publisher ?? '');
    final TextEditingController editionController =
      TextEditingController(text: book?.edition ?? '');
    final TextEditingController languageController =
      TextEditingController(text: book?.language ?? 'English');
    final TextEditingController yearController = TextEditingController(
      text: book?.publishedYear?.toString() ?? '',
    );
    final TextEditingController priceController = TextEditingController(
      text: book != null && book.unitPrice > 0 ? book.unitPrice.toStringAsFixed(0) : '',
    );
    final TextEditingController reorderController = TextEditingController(
      text: (book?.reorderLevel ?? 1).toString(),
    );
    final TextEditingController tagsController = TextEditingController(
      text: book?.tags.join(', ') ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: book?.description ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(book == null ? 'Add Book' : 'Edit Book'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: isbnController,
                  decoration: const InputDecoration(labelText: 'ISBN'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: copiesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Copies'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: branchController,
                  decoration: const InputDecoration(labelText: 'Branch'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rackController,
                  decoration: const InputDecoration(labelText: 'Rack / Shelf'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: publisherController,
                  decoration: const InputDecoration(labelText: 'Publisher'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: editionController,
                  decoration: const InputDecoration(labelText: 'Edition'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: languageController,
                  decoration: const InputDecoration(labelText: 'Language'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Published Year'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit Price'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reorderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reorder Level'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 3,
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
                final String title = titleController.text.trim();
                final String author = authorController.text.trim();
                final String isbn = isbnController.text.trim();
                final int? copies = int.tryParse(copiesController.text.trim());
                final int? year = yearController.text.trim().isEmpty
                    ? null
                    : int.tryParse(yearController.text.trim());
                final double price = double.tryParse(priceController.text.trim()) ?? 0;
                final int reorderLevel = int.tryParse(reorderController.text.trim()) ?? 1;
                final List<String> tags = tagsController.text
                  .split(',')
                  .map((String value) => value.trim())
                  .where((String value) => value.isNotEmpty)
                  .toList();
                final String description = descriptionController.text.trim();

                if (title.isEmpty || author.isEmpty || isbn.isEmpty || copies == null || copies <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid book details.')),
                  );
                  return;
                }

                if (book == null) {
                  provider.addBook(
                    title: title,
                    author: author,
                    isbn: isbn,
                    totalCopies: copies,
                    category: categoryController.text.trim(),
                    branch: branchController.text.trim(),
                    rack: rackController.text.trim(),
                    publisher: publisherController.text.trim(),
                    edition: editionController.text.trim(),
                    language: languageController.text.trim(),
                    publishedYear: year,
                    unitPrice: price,
                    reorderLevel: reorderLevel,
                    tags: tags,
                    description: description,
                  );
                } else {
                  provider.updateBook(
                    book.id,
                    title: title,
                    author: author,
                    isbn: isbn,
                    totalCopies: copies,
                    category: categoryController.text.trim(),
                    branch: branchController.text.trim(),
                    rack: rackController.text.trim(),
                    publisher: publisherController.text.trim(),
                    edition: editionController.text.trim(),
                    language: languageController.text.trim(),
                    publishedYear: year,
                    unitPrice: price,
                    reorderLevel: reorderLevel,
                    tags: tags,
                    description: description,
                  );
                }

                Navigator.pop(dialogContext);
              },
              child: Text(book == null ? 'Create' : 'Update'),
            ),
          ],
        );
      },
    );
  }
}
