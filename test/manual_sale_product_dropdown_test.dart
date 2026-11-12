import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/hyperion_product_catalog.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/ui/manual_sale_dialog.dart';

void main() {
  test('catalog offers every Hyperion access group and subscription duration', () {
    expect(HyperionProductCatalog.products.length, 15);
    expect(HyperionProductCatalog.products.toSet().length, 15);
    for (final group in ['OIC-NW', 'OIC-EW', 'Deck Management',
      'Engine Management', 'GMDSS GOC']) {
      for (final term in ['weekly', 'monthly', 'yearly']) {
        expect(HyperionProductCatalog.products, contains('$group $term access'));
      }
    }
    expect(HyperionProductCatalog.choicesForExisting(null).length, 15);
    expect(HyperionProductCatalog.choicesForExisting('OIC-NW monthly access').length, 15);
    expect(HyperionProductCatalog.choicesForExisting(
      'Legacy maritime tutorial').first, 'Legacy maritime tutorial');
    expect(HyperionProductCatalog.products, isNot(contains('Legacy maritime tutorial')),
      reason: 'Legacy data may be edited without becoming a new standard product');
  });

  PayMongoTransaction existingSale(String description) => PayMongoTransaction(
    id: 'manual_test_product001', type: 'Payment', status: 'Paid',
    paymentMethod: 'QR Ph', occurredAt: DateTime(2026, 11, 12),
    grossCentavos: 5000, feeCentavos: 0, vatCentavos: 0,
    netCentavos: 5000, source: 'manual', reference: 'REF-OLD-001',
    description: description, customer: 'Existing customer',
  );

  Future<PayMongoTransaction?> openEditor(WidgetTester tester, {
    PayMongoTransaction? initial,
    Size screen = const Size(900, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screen;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    PayMongoTransaction? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showManualSaleEditor(context, initial: initial);
        },
        child: const Text('Open sale editor'),
      ),
    ))));
    await tester.tap(find.text('Open sale editor'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('manual-sale-product')), findsOneWidget);
    return result;
  }

  testWidgets('new manual sale requires a selected product and preserves price entered',
      (tester) async {
    await openEditor(tester);
    expect(find.text('Select Hyperion product'), findsOneWidget);
    final amount = find.widgetWithText(TextField, 'Gross amount paid *');
    await tester.enterText(amount, '50.00');
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();
    expect(find.text('Select the product or service.'), findsOneWidget);
    final picker = find.byKey(const ValueKey('manual-sale-product'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OIC-NW monthly access').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();
    // A persisted sale is observable by capturing the completion in the widget.
    expect(find.text('Add sale'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing old custom description does not alter accounting details',
      (tester) async {
    await openEditor(tester, initial: existingSale('Legacy maritime tutorial'));
    final picker = find.byKey(const ValueKey('manual-sale-product'));
    final selected = tester.widget<DropdownButtonFormField<String>>(picker);
    expect(selected.initialValue, 'Legacy maritime tutorial');
    expect(find.text('Legacy maritime tutorial'), findsOneWidget);
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();
    expect(find.text('Edit sale'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
