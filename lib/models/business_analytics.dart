import 'book_entry.dart';
import 'paymongo_transaction.dart';

class DailyBusinessMetric {
  final DateTime date;
  final int grossPaymongo;
  final int provisionalGooglePlay;
  final int processingFees;
  final int manualExpenses;
  final int bankPayouts;
  final int manualDirectReceipts;
  final int payments;
  final int adjustments;

  const DailyBusinessMetric({
    required this.date, required this.grossPaymongo,
    required this.provisionalGooglePlay, required this.processingFees,
    required this.manualExpenses, required this.bankPayouts,
    required this.payments, required this.adjustments,
  });

  int get trackedReceipts => grossPaymongo + provisionalGooglePlay;
  int get trackedCosts => processingFees + manualExpenses;
  int get cashMovement => bankPayouts + manualDirectReceipts - manualExpenses;
}

class BusinessAnalytics {
  final int days;
  final DateTime start;
  final DateTime end;
  final List<DailyBusinessMetric> timeline;
  final List<BookEntry> recentExpenses;
  final List<PayMongoTransaction> recentSales;
  final Map<String, int> expenseCategories;
  final int grossPaymongo;
  final int provisionalGooglePlay;
  final int fees;
  final int manualExpenses;
  final int bankPayouts;
  final int salesCount;
  final int adjustmentNet;
  final int adjustmentsCount;

  const BusinessAnalytics({
    required this.days, required this.start, required this.end,
    required this.timeline, required this.recentExpenses,
    required this.recentSales, required this.expenseCategories,
    required this.grossPaymongo, required this.provisionalGooglePlay,
    required this.fees, required this.manualExpenses,
    required this.bankPayouts, required this.manualDirectReceipts,
    required this.salesCount,
    required this.adjustmentNet, required this.adjustmentsCount,
  });

  /// Indicative only: PayMongo CSV gross collections plus provisional
  /// Google Play payout receipts; NOT validated tax revenue or net profit.
  int get trackedReceipts => grossPaymongo + provisionalGooglePlay;
  int get trackedCosts => fees + manualExpenses;
  int get indicativeResult => trackedReceipts - trackedCosts;
  int get cashMovement => bankPayouts - manualExpenses;

  factory BusinessAnalytics.fromSources({
    required Iterable<BookEntry> entries,
    required Iterable<PayMongoTransaction> paymongo,
    required DateTime now,
    int days = 30,
  }) {
    if (days < 1 || days > 366) {
      throw ArgumentError.value(days, 'days', 'Use 1–366 days');
    }
    final last = DateTime(now.year, now.month, now.day);
    final first = last.subtract(Duration(days: days - 1));
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final filteredEntries = entries.where(
      (e) => !e.deleted && !dateOnly(e.date).isBefore(first) &&
        !dateOnly(e.date).isAfter(last)).toList();
    final imported = paymongo.where(
      (t) => !dateOnly(t.occurredAt).isBefore(first) &&
        !dateOnly(t.occurredAt).isAfter(last)).toList();
    final slots = List.generate(days, (i) => first.add(Duration(days: i)));
    final income = <DateTime, int>{};
    final provisional = <DateTime, int>{};
    final feesByDate = <DateTime, int>{};
    final expensesByDate = <DateTime, int>{};
    final bankByDate = <DateTime, int>{};
    final salesByDate = <DateTime, int>{};
    final adjustmentByDate = <DateTime, int>{};
    final categories = <String, int>{};
    var gross = 0, google = 0, fees = 0, expenses = 0, bank = 0;
    var manualDirect = 0;
    var sales = 0, adjustmentNet = 0, adjustmentCount = 0;
    for (final txn in imported) {
      final date = dateOnly(txn.occurredAt);
      if (txn.isPayment) {
        sales++;
        if (txn.isManual) manualDirect += txn.netCentavos;
        gross += txn.grossCentavos;
        fees += -txn.feeCentavos;
        income[date] = (income[date] ?? 0) + txn.grossCentavos;
        feesByDate[date] = (feesByDate[date] ?? 0) - txn.feeCentavos;
        salesByDate[date] = (salesByDate[date] ?? 0) + 1;
      } else {
        adjustmentCount++;
        adjustmentNet += txn.netCentavos;
        adjustmentByDate[date] = (adjustmentByDate[date] ?? 0) +
            txn.netCentavos;
      }
    }
    for (final e in filteredEntries) {
      final date = dateOnly(e.date);
      if (e.kind == EntryKind.expense) {
        expenses += e.amountCentavos;
        expensesByDate[date] = (expensesByDate[date] ?? 0) +
            e.amountCentavos;
        final category = e.category.isEmpty ? 'Uncategorized' : e.category;
        categories[category] = (categories[category] ?? 0) +
            e.amountCentavos;
      } else {
        bank += e.amountCentavos;
        bankByDate[date] = (bankByDate[date] ?? 0) +
            e.amountCentavos;
        if (e.platform == 'Google Play') {
          google += e.receiptsCentavos;
          provisional[date] = (provisional[date] ?? 0) + e.receiptsCentavos;
        }
      }
    }
    imported.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recentExpenses = filteredEntries
        .where((e) => e.kind == EntryKind.expense).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return BusinessAnalytics(
      days: days, start: first, end: last,
      grossPaymongo: gross, provisionalGooglePlay: google,
      fees: fees, manualExpenses: expenses, bankPayouts: bank,
      manualDirectReceipts: manualDirect,
      salesCount: sales, adjustmentNet: adjustmentNet,
      adjustmentsCount: adjustmentCount,
      expenseCategories: Map.unmodifiable(categories),
      recentExpenses: List.unmodifiable(recentExpenses.take(5)),
      recentSales: List.unmodifiable(imported.where((t) => t.isPayment).take(5)),
      timeline: List.unmodifiable(slots.map((d) => DailyBusinessMetric(
        date: d, grossPaymongo: income[d] ?? 0,
        provisionalGooglePlay: provisional[d] ?? 0,
        processingFees: feesByDate[d] ?? 0,
        manualExpenses: expensesByDate[d] ?? 0,
        bankPayouts: bankByDate[d] ?? 0,
        payments: salesByDate[d] ?? 0,
        adjustments: adjustmentByDate[d] ?? 0,
      ))),
    );
  }
}
