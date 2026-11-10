import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/dashboard_metrics.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';

PayMongoTransaction paid(String id, DateTime date, {
  int gross = 10000, int fee = -200,
  String method = 'qrph', String description = '',
  bool manual = false,
}) => PayMongoTransaction(
  id: id, type: 'Payment', status: 'Paid', paymentMethod: method,
  occurredAt: date, grossCentavos: gross, feeCentavos: fee,
  vatCentavos: 0, netCentavos: gross + fee,
  source: manual ? 'manual' : 'import', description: description,
);

BookEntry entry(String id, DateTime date, EntryKind kind, int amount) =>
    BookEntry(
      id: id, userId: 'local', kind: kind, date: date,
      platform: kind == EntryKind.payout ? 'PayMongo' : '',
      description: kind == EntryKind.expense ? 'Website hosting' : '',
      category: kind == EntryKind.expense ? 'Software' : '',
      amountCentavos: amount,
    );

void main() {
  final now = DateTime(2026, 11, 10);

  test('KPIs separate actual sales from payout transfers', () {
    final snapshot = DashboardMetrics.calculate(
      now: now, days: 7,
      transactions: [
        paid('pay_dashboard001', DateTime(2026, 11, 9)),
        paid('manual_dashboard001', now, gross: 5000, fee: 0,
          method: 'Bank Transfer', description: 'OIC-NW monthly',
          manual: true),
      ],
      entries: [
        entry('payout_dashboard001', now, EntryKind.payout, 9800),
        entry('expense_dashboard001', now, EntryKind.expense, 1000),
      ],
    );
    expect(snapshot.revenue, 15000,
      reason: 'Bank payout is only a transfer, not new revenue');
    expect(snapshot.salesCount, 2);
    expect(snapshot.knownCosts, 300);
    expect(snapshot.indicativeResult, 14700);
    expect(snapshot.cashMovement, 13800,
      reason: 'Bank payout plus directly received cash less expenses');
    expect(snapshot.salesByMethod['qrph'], 10000);
    expect(snapshot.salesByMethod['Bank Transfer'], 5000);
    expect(snapshot.salesByCategory['Uncategorized sales'], 10000);
    expect(snapshot.salesByCategory['OIC-NW monthly'], 5000);
    expect(snapshot.cashDays.last.net, 13800);
    expect(snapshot.cashDays[snapshot.cashDays.length - 2].net, 0);
    expect(snapshot.analytics.timeline.last.manualDirectReceipts, 5000);
    expect(snapshot.analytics.timeline.last.bankPayouts, 9800);
    expect(snapshot.analytics.timeline.last.manualExpenses, 1000);
  });

  test('daily cash flow includes negative expense days', () {
    final snapshot = DashboardMetrics.calculate(
      now: now, days: 7, transactions: [],
      entries: [
        entry('expense_previous001', DateTime(2026, 11, 9),
          EntryKind.expense, 4750),
      ],
    );
    expect(snapshot.cashDays[snapshot.cashDays.length - 2].net, -4750);
    expect(snapshot.cashDays.last.net, 0);
    expect(snapshot.revenue, 0);
    expect(snapshot.knownCosts, 4750);
    expect(snapshot.indicativeResult, -4750);
  });

  test('period filter changes KPI, chart and recent sales together', () {
    final sales = [
      paid('pay_oldperiod001', DateTime(2026, 10, 20),
        gross: 20000, fee: 0),
      paid('pay_newperiod001', now, gross: 3000, fee: 0),
    ];
    final seven = DashboardMetrics.calculate(
      now: now, days: 7, entries: [], transactions: sales);
    final thirty = DashboardMetrics.calculate(
      now: now, days: 30, entries: [], transactions: sales);
    expect(seven.salesCount, 1);
    expect(seven.revenue, 3000);
    expect(seven.cashDays.length, 7);
    expect(thirty.salesCount, 2);
    expect(thirty.revenue, 23000);
    expect(thirty.cashDays.length, 30);
    expect(thirty.analytics.recentSales.length, 2);
  });

  test('refund or adjustment is never shown as an additional paid sale', () {
    final refunded = PayMongoTransaction(
      id: 'refund_dashboard001', type: 'Refund', status: 'Refunded',
      paymentMethod: 'qrph', occurredAt: now,
      grossCentavos: -1000, feeCentavos: 0,
      vatCentavos: 0, netCentavos: -1000,
    );
    final snapshot = DashboardMetrics.calculate(
      now: now, days: 7, entries: [], transactions: [refunded]);
    expect(snapshot.salesCount, 0);
    expect(snapshot.revenue, 0);
    expect(snapshot.salesByCategory, isEmpty);
    expect(snapshot.salesByMethod, isEmpty);
    expect(snapshot.analytics.adjustmentsCount, 1);
  });
}
