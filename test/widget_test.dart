import 'package:flutter_test/flutter_test.dart';

import 'package:lms/main.dart';

void main() {
  testWidgets('App loads home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const LibraryManagementApp());

    expect(find.textContaining('LMS -'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });
}
