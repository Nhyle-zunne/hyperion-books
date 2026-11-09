import 'book_entry.dart';
import 'paymongo_transaction.dart';

/// Local management totals, not tax-return or statutory accounting values.
/// Never counts a PayMongo bank payout as an additional sale when CSV payments
/// exist. Google Play and unsupported payouts remain provisional.
class TaxPeriodSummary {
  final int paymongoGross;
  final int provisionalOtherReceipts;
  final int processorFees;
  final int manualExpenses;
  final int bankDeposits;
  final int adjustmentsPendingReview;
  final int paymentCount;
  const TaxPeriodSummary({
    required this.paymongoGross,
    required this.provisionalOtherReceipts,
    required this.processorFees,
    required this.manualExpenses,
    required this.bankDeposits,
    required this.adjustmentsPendingReview,
    required this.paymentCount,
  });

  int get trackedReceipts => paymongoGross + provisionalOtherReceipts;
  int get knownCosts => processorFees + manualExpenses;
  int get indicativeResult => trackedReceipts - knownCosts;
  int get bankMovement => bankDeposits - manualExpenses;

  static TaxPeriodSummary between({
    required Iterable<BookEntry> entries,
    required Iterable<PayMongoTransaction> transactions,
    required DateTime first,
    required DateTime last,
  }) {
    bool inside(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(first) && !day.isAfter(last);
    }
    final imported = transactions.toList();
    final hasPaymentCsv = imported.any((t) => t.isPayment);
    var gross = 0, provisional = 0, fees = 0, expenses = 0;
    var deposits = 0, adjustments = 0, payments = 0;
    for (final t in imported.where((t) => inside(t.occurredAt))) {
      if (t.isPayment) {
        payments++;
        gross += t.grossCentavos;
        fees += -t.feeCentavos;
      } else {
        adjustments += t.netCentavos;
      }
    }
    for (final e in entries.where((e) => !e.deleted && inside(e.date))) {
      if (e.kind == EntryKind.expense) {
        expenses += e.amountCentavos;
      } else {
        deposits += e.amountCentavos;
        if (e.platform != 'PayMongo' || !hasPaymentCsv) {
          provisional += e.receiptsCentavos;
        }
      }
    }
    return TaxPeriodSummary(
      paymongoGross: gross, provisionalOtherReceipts: provisional,
      processorFees: fees, manualExpenses: expenses,
      bankDeposits: deposits, adjustmentsPendingReview: adjustments,
      paymentCount: payments);
  }
}
