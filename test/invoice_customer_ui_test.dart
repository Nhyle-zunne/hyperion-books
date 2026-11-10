import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/ui/tax_filing_page.dart';

void main() {
  testWidgets('linked invoice draft prefills buyer data without issuing invoice',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1020, 980);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final paid = PayMongoTransaction(
      id: 'pay_invoicebuyer001', type: 'Payment', status: 'Paid',
      paymentMethod: 'qrph', occurredAt: DateTime(2026, 11, 9, 12),
      grossCentavos: 12000, feeCentavos: -200,
      vatCentavos: -21, netCentavos: 11800,
      customer: 'Sample Buyer', customerEmail: 'sample@example.test',
      customerPhone: '+639000000000', customerAddress: 'Cebu City',
      customerTin: '123-456-789', description: 'Review subscription',
    );
    BusinessWorkspace saved = const BusinessWorkspace();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: TaxFilingPage(
        initialSection: 5, initialSaleId: paid.id,
        entries: const [], transactions: [paid],
        workspace: saved, save: (next) async { saved = next; },
      ))));
    await tester.pumpAndSettle();

    expect(find.text('New Invoice record'), findsOneWidget);
    expect(find.text('Linked paid sale: pay_invoicebuyer001'), findsOneWidget);
    await tester.tap(find.text('Save locally'));
    await tester.pumpAndSettle();
    expect(saved.taxRecords.length, 1);
    final invoice = saved.taxRecords.single;
    expect(invoice.kind, 'Invoice');
    expect(invoice.name, 'Sample Buyer');
    expect(invoice.buyerEmail, 'sample@example.test');
    expect(invoice.buyerPhone, '+639000000000');
    expect(invoice.buyerAddress, 'Cebu City');
    expect(invoice.buyerTin, '123-456-789');
    expect(invoice.sourceSaleId, paid.id);
    expect(invoice.amountCentavos, 12000);
    expect(invoice.reference, isEmpty,
      reason: 'App must not invent a BIR-authorized invoice serial number.');
  });
}
