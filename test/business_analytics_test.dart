import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/models/business_analytics.dart';

PayMongoTransaction sale({required String id, required DateTime date,
  int gross = 10000, int fee = -150, int net = 9850}) =>
  PayMongoTransaction(id: id, type: 'Payment', status: 'Paid',
    paymentMethod: 'qrph', occurredAt: date,
    grossCentavos: gross, feeCentavos: fee,
    vatCentavos: -16, netCentavos: net);

BookEntry entry({required String id, required EntryKind kind,
  required DateTime date, required int amount,
  String platform = 'PayMongo'}) =>
  BookEntry(id: id, userId: 'local', kind: kind, date: date,
    platform: kind == EntryKind.payout ? platform : '',
    description: kind == EntryKind.expense ? 'Hosting' : '',
    category: kind == EntryKind.expense ? 'Software' : '',
    amountCentavos: amount);

void main() {
  final day = DateTime(2026, 11, 10);
  test('bank payout does not add revenue after CSV sale', () {
    final analytics = BusinessAnalytics.fromSources(
      now: day, days: 7,
      paymongo: [sale(id: 'pay_001', date: day)],
      entries: [
        entry(id: 'payout_001', kind: EntryKind.payout,
          date: day, amount: 9850),
        entry(id: 'expense_001', kind: EntryKind.expense,
          date: day, amount: 2000),
      ]);
    expect(analytics.grossPaymongo, 10000);
    expect(analytics.fees, 150);
    expect(analytics.manualExpenses, 2000);
    expect(analytics.bankPayouts, 9850);
    expect(analytics.trackedReceipts, 10000);
    expect(analytics.trackedCosts, 2150);
    expect(analytics.indicativeResult, 7850);
    expect(analytics.cashMovement, 7850);
    expect(analytics.salesCount, 1);
    expect(analytics.expenseCategories['Software'], 2000);
    expect(analytics.timeline.last.grossPaymongo, 10000);
  });

  test('adjustment is not treated as another customer sale', () {
    final adjustment = PayMongoTransaction(
      id: 'adj_002', type: 'Adjustment', status: 'Succeeded',
      paymentMethod: 'Not applicable', occurredAt: day,
      grossCentavos: -1640, feeCentavos: 0,
      vatCentavos: 0, netCentavos: -1640);
    final result = BusinessAnalytics.fromSources(
      now: day, days: 7, entries: [], paymongo: [adjustment]);
    expect(result.salesCount, 0);
    expect(result.trackedReceipts, 0);
    expect(result.adjustmentsCount, 1);
    expect(result.adjustmentNet, -1640);
  });

  test('range excludes transactions outside calendar window', () {
    final old = sale(id: 'pay_old001',
      date: DateTime(2026, 10, 20));
    final newSale = sale(id: 'pay_recent001',
      date: DateTime(2026, 11, 9));
    final result = BusinessAnalytics.fromSources(
      now: day, days: 7, entries: [],
      paymongo: [old, newSale]);
    expect(result.salesCount, 1);
    expect(result.timeline.length, 7);
    expect(result.start, DateTime(2026, 11, 4));
    expect(result.end, day);
  });

  test('manual Google Play receipts remain provisional', () {
    final result = BusinessAnalytics.fromSources(
      now: day, days: 7, paymongo: [],
      entries: [
        entry(id: 'google_001', kind: EntryKind.payout, date: day,
          amount: 3000, platform: 'Google Play'),
      ]);
    expect(result.provisionalGooglePlay, 3000);
    expect(result.trackedReceipts, 3000);
    expect(result.cashMovement, 3000);
  });
}
