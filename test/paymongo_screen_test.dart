import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/ui/paymongo_screen.dart';

void main() {
  testWidgets('General Sales view fits mobile and exposes imports and template',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var imports = 0;
    var templates = 0;
    final sample = PayMongoTransaction(
      id: 'pay_test0001', type: 'Payment', status: 'Paid',
      paymentMethod: 'qrph', occurredAt: DateTime(2026, 11, 5, 23, 12),
      grossCentavos: 5000, feeCentavos: -75,
      vatCentavos: -8, netCentavos: 4925,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PayMongoScreen(
      transactions: [sample],
      onImport: () => imports++,
      onExport: () {},
      onTemplate: () => templates++,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Gross sales'), findsOneWidget);
    expect(find.text('Net sales after fees'), findsOneWidget);
    expect(find.text('Import Sales CSV / Excel'), findsOneWidget);
    expect(find.textContaining('PayMongo'), findsNothing);
    expect(find.text('Sales CSV template'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Import Sales CSV / Excel'));
    expect(imports, 1);
    await tester.tap(find.text('Sales CSV template'));
    expect(templates, 1);
    expect(tester.takeException(), isNull);
  });
}
