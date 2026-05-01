# Library Management System (Flutter)

A complete Flutter app for managing a library with:

- Dashboard analytics
- Book management (add, edit, delete, search)
- Member management (add, edit, delete)
- Issue and return workflow with custom borrow days
- Active issue tracking and return history
- Overdue tracking and fine collection
- Settings for fine rate and default borrow period
- Borrow limit per member and renewal limit per issue
- Reservation/waitlist and auto-issue when copies return
- Reports for top books and top members
- Offline local persistence using SharedPreferences
- CSV export for circulation records
- Full JSON backup and restore tools
- Waitlist management with manual queue control
- Book sorting, low-stock filtering, and member search
- Monthly issue trend and low-stock analytics
- Role switching (Admin/Librarian/Guest) with permission gating
- Audit log timeline with CSV export
- PDF report sharing
- PIN-protected role switching and admin PIN update
- Fine payment receipt PDF sharing
- Date-range filtered reports and searchable audit logs
- Branch-aware catalog metadata (branch, rack, category, publisher, edition, language)
- Rich membership records (membership ID, type, department, address, status, expiry)
- Inventory valuation and larger-library dashboard metrics
- Procurement/acquisition management with vendor, invoice, and branch tracking
- Damaged/lost inventory workflows and reorder-level monitoring
- Vendor master management (contact, GST, terms, rating)
- Copy-level accession tracking with branch/rack transfer and status updates
- Member financial ledger (penalty/payment/waiver) with approval workflow
- Configurable circulation policy to block new issues when outstanding balance exceeds threshold
- Optional accession-level copy selection during issue workflow
- CSV exports for vendor master, physical copy inventory, member ledger, and catalog books
- Bulk CSV imports for books, members, and vendors with upsert support

## Tech Stack

- Flutter
- Provider (state management)
- Intl (date formatting)
- UUID (ID generation)
- SharedPreferences (offline storage)
- PDF + Printing (report sharing)

## Project Structure

- `lib/models` - Data models (`Book`, `Member`, `BorrowRecord`, `Vendor`, `BookCopy`, `MemberLedgerEntry`)
- `lib/providers` - `LibraryProvider` business logic and state
- `lib/screens` - UI tabs and main screen
- `lib/widgets` - Reusable components

## Prerequisites

Install Flutter SDK and add it to PATH:

- https://docs.flutter.dev/get-started/install

Then run:

```bash
flutter doctor
```

## Run the App

From project root:

```bash
flutter pub get
flutter run
```

## Features Included

1. Dashboard with key metrics
2. Full book CRUD with validation and search
3. Full member CRUD with safeguards
4. Prevent deleting books/members with active issues
5. Issue book only when copies are available
6. Issue with configurable borrow days
7. Return books and auto-update availability
8. Automatic overdue fine calculation
9. Fine payment during return and post-return collection
10. Record search and status filters (active, overdue, returned, all)
11. Reports tab (collection summary, top books, top members)
12. Persistent app data across restarts
13. Borrow renewals with renewal cap
14. Reservations and waitlist queue support
15. Automatic issue from waitlist when returned
16. Member/book operational stats in list views
17. CSV report export to clipboard
18. Full data backup (JSON export) and restore (JSON import)
19. Admin reset with seed data restore
20. Books: sort by title/availability/popularity/waitlist, low-stock filter
21. Members: search by name/email/phone
22. Reports: monthly issue trends and low stock alerts
23. Waitlist manager to remove reservations manually
24. Role-based permissions for operational controls
25. Admin audit logs with export
26. Shareable PDF report generation
27. PIN-protected role switching and PIN rotation
28. Fine receipt PDF generation from return/collection actions
29. Report filters by date range with scoped CSV/PDF exports
30. Audit filters by search text, role, and date range
31. Rich book records for larger library catalog management
32. Rich member profiles with membership lifecycle tracking
33. Branch/category/inventory-value analytics on dashboard
34. Acquisition records and procurement spend tracking
35. Damaged/lost inventory tracking and reorder monitoring
36. Vendor registry with edit/delete safeguards
37. Physical copy inventory tab for accession-level operations
38. Member ledger with pending penalty approvals
39. Enterprise dashboard/report metrics for vendors, tracked copies, and approvals
40. Due-today and due-soon operational alerts
41. Fine outstanding policy controls in settings (issue blocking threshold)
42. Issue workflow with optional specific physical copy selection
43. Fine-block policy based on outstanding member ledger balance
44. CSV exports across vendor, copy, ledger, and books modules
45. Bulk CSV import workflows for books, members, and vendors (with update-existing mode)

## Notes

- Seed/demo data is included for first-time app launch.
- All data changes are persisted locally and restored on next launch.
- Default admin PIN is `1234` and should be changed from Settings.
- Sample data now includes branch, category, rack, pricing, and membership metadata for larger-library testing.
- Seed data also includes sample vendor, procurement, and a pending ledger penalty for enterprise workflow testing.
