import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/ui/dashboard_overview.dart';

void main() {
  Future<void> render(WidgetTester tester, Size size, {
    VoidCallback? addSale,
    VoidCallback? viewSales,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now();
    final sale = PayMongoTransaction(
      id: 'pay_dashtest_001', type: 'Payment', status: 'Paid',
      occurredAt: now, paymentMethod: 'qrph',
      grossCentavos: 10000, feeCentavos: -150, vatCentavos: -16,
      netCentavos: 9850, customer: 'Test customer');
    final expense = BookEntry(
      id: 'expense_dashtest_001', userId: 'local',
      kind: EntryKind.expense, date: now,
      platform: '', description: 'Hosting', category: 'Software',
      amountCentavos: 2500);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: DashboardOverview(
        entries: [expense], sales: [sale],
        onSales: viewSales ?? () {},
        onExpenses: () {}, onBooks: () {}, onReports: () {},
        onAddSale: addSale ?? () {}, onAddExpense: () {},
        onAddPayout: () {}, onExport: () {}, onBackup: () {},
      ),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop uses 4 aligned KPIs and 2 top charts', (tester) async {
    await render(tester, const Size(1280, 900));
    for (final name in [
      'Financial overview','Tracked revenue','Indicative result',
      'Known costs','Paid sales','Revenue vs Expenses','Sales by Category',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    final first = tester.getTopLeft(find.byKey(
      const ValueKey('kpi-tracked-revenue')));
    final second = tester.getTopLeft(find.byKey(
      const ValueKey('kpi-indicative-result')));
    final third = tester.getTopLeft(find.byKey(
      const ValueKey('kpi-known-costs')));
    final fourth = tester.getTopLeft(find.byKey(
      const ValueKey('kpi-paid-sales')));
    expect(first.dy, second.dy);
    expect(second.dy, third.dy);
    expect(third.dy, fourth.dy);
    expect(first.dx, lessThan(second.dx));
    expect(second.dx, lessThan(third.dx));
    expect(third.dx, lessThan(fourth.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout has no overflow and chart mode changes', (tester) async {
    var added = 0;
    await render(tester, const Size(360, 760), addSale: () => added++);
    expect(find.text('Financial overview'), findsOneWidget);
    expect(find.text('Tracked revenue'), findsOneWidget);
    expect(find.text('Known costs'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-days-7')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final menu = find.byKey(const ValueKey('dashboard-breakdown-mode'));
    final page = find.byKey(const PageStorageKey<String>('hyperion-dashboard'));
    await tester.scrollUntilVisible(menu, 220, scrollable: find.descendant(
      of: page, matching: find.byType(Scrollable)).first);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('By payment method').last);
    await tester.pumpAndSettle();
    expect(find.text('Sales by Payment Method'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Quick actions'), 300,
      scrollable: find.descendant(
        of: page, matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Add sale').last);
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales KPI is actually navigable', (tester) async {
    var opened = 0;
    await render(tester, const Size(1000, 800),
      viewSales: () => opened++);
    await tester.tap(find.byKey(const ValueKey('kpi-paid-sales')));
    await tester.pump();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
