import 'business_analytics.dart';
import 'book_entry.dart';
import 'paymongo_transaction.dart';

/// Lightweight, auditable dashboard projection. It never modifies source data.
/// Revenue is provisional: provider imports are not verified tax invoices.
class DashboardMetrics {
  final BusinessAnalytics analytics;
  final Map<String, int> salesByMethod;
  final Map<String, int> salesByCategory;
  final List<DashboardCashDay> cashDays;

  const DashboardMetrics({
    required this.analytics,
    required this.salesByMethod,
    required this.salesByCategory,
    required this.cashDays,
  });

  int get revenue => analytics.trackedReceipts;
  int get knownCosts => analytics.trackedCosts;
  int get indicativeResult => analytics.indicativeResult;
  int get salesCount => analytics.salesCount;
  int get cashMovement => analytics.cashMovement;
  int get provisionalGooglePlay => analytics.provisionalGooglePlay;

  /// A payout is NOT a sale. Group imported customer payments by their
  /// recorded method, and group manual payments by their actual method.
  static DashboardMetrics calculate({
    required Iterable<BookEntry> entries,
    required Iterable<PayMongoTransaction> transactions,
    required DateTime now,
    int days = 30,
  }) {
    final analytics = BusinessAnalytics.fromSources(
      entries: entries, paymongo: transactions, now: now, days: days);
    final method = <String, int>{};
    final category = <String, int>{};
    DateTime dateOnly(DateTime value) =>
        DateTime(value.year, value.month, value.day);
    for (final txn in transactions) {
      final date = dateOnly(txn.occurredAt);
      if (!txn.isPayment || date.isBefore(analytics.start) ||
          date.isAfter(analytics.end)) {
        continue;
      }
      final name = txn.paymentMethod.trim().isEmpty
          ? 'Unspecified method'
          : txn.paymentMethod.trim();
      method[name] = (method[name] ?? 0) + txn.grossCentavos;
      final kind = txn.isManual && txn.description.trim().isNotEmpty
          ? txn.description.trim()
          : 'Uncategorized sales';
      category[kind] = (category[kind] ?? 0) + txn.grossCentavos;
    }
    final cash = analytics.timeline.map((day) => DashboardCashDay(
      date: day.date,
      deposits: day.bankPayouts + day.manualDirectReceipts,
      expenses: day.manualExpenses,
    )).toList();
    return DashboardMetrics(
      analytics: analytics,
      salesByMethod: Map.unmodifiable(method),
      salesByCategory: Map.unmodifiable(category),
      cashDays: List.unmodifiable(cash),
    );
  }
}

class DashboardCashDay {
  final DateTime date;
  final int deposits, expenses;
  const DashboardCashDay({
    required this.date, required this.deposits, required this.expenses,
  });
  int get net => deposits - expenses;
}
