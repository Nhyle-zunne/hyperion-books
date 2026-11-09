import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/ui/accounting_books_page.dart';
import 'package:hyperion_books/ui/books_compact_table.dart';

void main() {
  testWidgets('Books page keeps filters and concise table visible without horizontal scrolling',
    (tester) async {
    tester.view.physicalSize = const Size(980, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final payment = PayMongoTransaction(
      id: 'pay_testtable123', type: 'Payment', status: 'Paid',
      paymentMethod: 'qrph', occurredAt: DateTime(2026, 11, 3, 11, 25),
      grossCentavos: 120000, feeCentavos: -3000,
      vatCentavos: -320, netCentavos: 117000);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AccountingBooksPage(
        entries: const [],
        transactions: [payment],
        workspace: const BusinessWorkspace(businessName: 'Sample'),
        save: (_) async {},
      ))));
    await tester.pumpAndSettle();

    expect(find.text('Books of Accounts'), findsOneWidget);
    expect(find.text('COVERED PERIOD'), findsOneWidget);
    expect(find.text('Export to Excel'), findsOneWidget);
    expect(find.text('Show all dates'), findsOneWidget);
    expect(find.byType(Scrollbar), findsWidgets);
    expect(find.byType(BooksCompactTable), findsOneWidget);
    expect(find.text('Account / particulars'), findsOneWidget);
    expect(find.text('Debit (₱)'), findsOneWidget);
    expect(find.text('Credit (₱)'), findsOneWidget);

    await tester.ensureVisible(find.text('General Journal'));
    await tester.pumpAndSettle();
    expect(find.text('pay_testtable123'), findsWidgets);
  });

  testWidgets('full PayMongo source fields are available from a reference dialog',
    (tester) async {
    tester.view.physicalSize = const Size(1150, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final payment = PayMongoTransaction(
      id: 'pay_details123', type: 'Payment', status: 'Paid',
      paymentMethod: 'card', occurredAt: DateTime(2026, 11, 6, 9, 25),
      grossCentavos: 200000, feeCentavos: -6000,
      vatCentavos: -643, netCentavos: 194000);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AccountingBooksPage(
        entries: const [],
        transactions: [payment],
        workspace: const BusinessWorkspace(),
        save: (_) async {},
      ))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('pay_details123').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('pay_details123').first);
    await tester.pumpAndSettle();
    expect(find.text('Source transaction details'), findsOneWidget);
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Fee VAT component'), findsOneWidget);
  });

  testWidgets('narrow screen uses compact book cards without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final payment = PayMongoTransaction(
      id: 'pay_phonebook123', type: 'Payment', status: 'Paid',
      paymentMethod: 'qrph',
      occurredAt: DateTime(2026, 11, 4, 12),
      grossCentavos: 12500, feeCentavos: -200,
      vatCentavos: -21, netCentavos: 12300);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AccountingBooksPage(
        entries: const [], transactions: [payment],
        workspace: const BusinessWorkspace(),
        save: (_) async {},
      ))));
    await tester.pumpAndSettle();
    expect(find.byType(BooksCompactTable), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cash receipts'));
    await tester.pumpAndSettle();
    expect(find.text('Cash Receipts Journal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
