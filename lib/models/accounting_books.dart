import 'book_entry.dart';
import 'paymongo_transaction.dart';

/// Provisional source-based working books, not BIR-authorized computerized books.
/// PayMongo collections are separate from subsequent bank transfers.
class BookPosting {
  final String reference, account, particulars, source;
  final DateTime date;
  final int debit, credit;
  const BookPosting(this.reference, this.date, this.account,
      this.particulars, this.source, this.debit, this.credit);
}

class ReceiptRecord {
  final String reference, particulars, channel;
  final DateTime date;
  final int gross, fees, processorNet, bankReceived;
  final bool bankTransfer, provisional;
  const ReceiptRecord(this.reference, this.date, this.particulars,
      this.channel, this.gross, this.fees, this.processorNet,
      this.bankReceived, this.bankTransfer, this.provisional);
}

class DisbursementRecord {
  final String reference, particulars, account;
  final DateTime date;
  final int amount;
  const DisbursementRecord(this.reference, this.date,
      this.particulars, this.account, this.amount);
}

class LedgerPosting {
  final BookPosting posting;
  final int signedBalance;
  const LedgerPosting(this.posting, this.signedBalance);
  int get debitBalance => signedBalance > 0 ? signedBalance : 0;
  int get creditBalance => signedBalance < 0 ? -signedBalance : 0;
}

class AccountingBooks {
  static const bank = '1010 Cash / bank';
  static const clearing = '1020 PayMongo settlement clearing';
  static const sales = '4010 PayMongo sales (provisional)';
  static const google = '4020 Google Play receipts (provisional)';
  static const fees = '5010 PayMongo processing fees (VAT included)';
  static const deductions = '5090 Other platform deductions (review)';
  static const variance = '1090 Unreconciled PayMongo difference';
  static const adjustments = '2090 PayMongo adjustment (review)';
  static const refunds = '4090 PayMongo refunds (review)';
  static const unmatched = '4095 Unmatched payout receipts (review)';

  final List<ReceiptRecord> cashReceipts;
  final List<DisbursementRecord> cashDisbursements;
  final List<BookPosting> journal;
  final Map<String, List<LedgerPosting>> ledger;
  final List<String> warnings;
  final bool hasImportedPaymongo;

  const AccountingBooks({
    required this.cashReceipts, required this.cashDisbursements,
    required this.journal, required this.ledger,
    required this.warnings, required this.hasImportedPaymongo,
  });

  bool get balanced => journal.fold<int>(0, (v, x) => v + x.debit) ==
      journal.fold<int>(0, (v, x) => v + x.credit);
  int accountBalance(String account) => ledger[account]?.last.signedBalance ?? 0;

  static String monthOf(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}";

  factory AccountingBooks.fromSources(
      Iterable<BookEntry> entries, Iterable<PayMongoTransaction> transactions,
      {String? month}) {
    final allEntries = entries.where((e) => !e.deleted).toList();
    final allImported = transactions.toList();
    // Determine this from ALL periods; filtering must not reclassify a
    // later PayMongo bank transfer as new sales.
    final hasImported = allImported.isNotEmpty;
    bool inPeriod(DateTime d) =>
        month == null || month == 'All time' || monthOf(d) == month;
    final manual = allEntries.where((e) => inPeriod(e.date));
    final imported = allImported.where((e) => inPeriod(e.occurredAt));
    final journal = <BookPosting>[];
    final receipts = <ReceiptRecord>[];
    final disbursements = <DisbursementRecord>[];
    final warnings = <String>[];
    var adjustmentsCount = 0, mismatchCount = 0, grossOverrides = 0;

    void post(String ref, DateTime d, String account, String details,
        String source, int signedDebit) {
      if (signedDebit == 0) return;
      journal.add(BookPosting(ref, d, account, details, source,
          signedDebit > 0 ? signedDebit : 0,
          signedDebit < 0 ? -signedDebit : 0));
    }

    for (final t in imported) {
      final memo = '${t.type} via PayMongo';
      if (t.isPayment) {
        post(t.id, t.occurredAt, clearing, memo, 'PayMongo CSV', t.netCentavos);
        // PayMongo CSV Fee is negative, with its VAT portion already included.
        post(t.id, t.occurredAt, fees, memo, 'PayMongo CSV', -t.feeCentavos);
        post(t.id, t.occurredAt, sales, memo, 'PayMongo CSV', -t.grossCentavos);
        final diff = t.netCentavos - t.feeCentavos - t.grossCentavos;
        if (diff != 0) {
          post(t.id, t.occurredAt, variance, 'Gross/fee/net mismatch',
              'PayMongo CSV', -diff);
          mismatchCount++;
        }
        receipts.add(ReceiptRecord(t.id, t.occurredAt,
            'Customer payment - processor collection',
            'PayMongo clearing (not bank)', t.grossCentavos, -t.feeCentavos,
            t.netCentavos, 0, false, false));
      } else {
        adjustmentsCount++;
        // Refunds and adjustments are not assumed to be verified sales.
        post(t.id, t.occurredAt, clearing, memo, 'PayMongo CSV', t.netCentavos);
        post(t.id, t.occurredAt,
            t.type == 'Refund' ? refunds : adjustments,
            'Pending classification - $memo', 'PayMongo CSV', -t.netCentavos);
      }
    }

    for (final e in manual) {
      if (e.kind == EntryKind.expense) {
        final account = '5xxx Expense: ${e.category.isEmpty ? 'Uncategorized' : e.category}';
        final memo = e.description.isEmpty ? 'Expense paid' : e.description;
        post(e.id, e.date, account, memo, 'Manual expense', e.amountCentavos);
        post(e.id, e.date, bank, memo, 'Manual expense', -e.amountCentavos);
        disbursements.add(DisbursementRecord(e.id, e.date,
            memo, account, e.amountCentavos));
      } else if (e.platform == 'PayMongo' && hasImported) {
        final memo = e.description.isEmpty ? 'PayMongo payout to bank'
            : 'PayMongo payout to bank: ${e.description}';
        post(e.id, e.date, bank, memo, 'Manual bank payout', e.amountCentavos);
        post(e.id, e.date, clearing, memo, 'Manual bank payout', -e.amountCentavos);
        receipts.add(ReceiptRecord(e.id, e.date, memo,
            'Bank / PayMongo transfer', 0, 0, 0,
            e.amountCentavos, true, false));
        if (e.grossCentavos != null && e.grossCentavos != e.amountCentavos) {
          grossOverrides++;
        }
      } else {
        final memo = e.description.isEmpty ? '${e.platform} bank payout'
            : '${e.platform} bank payout: ${e.description}';
        final gross = e.receiptsCentavos;
        post(e.id, e.date, bank, memo, 'Manual bank payout', e.amountCentavos);
        post(e.id, e.date, deductions, memo, 'Manual bank payout',
            e.deductionCentavos);
        post(e.id, e.date,
            e.platform == 'Google Play' ? google : unmatched,
            memo, 'Manual bank payout', -gross);
        receipts.add(ReceiptRecord(e.id, e.date, memo,
            'Bank / ${e.platform}', gross, e.deductionCentavos,
            0, e.amountCentavos, false, true));
      }
    }

    int compare(DateTime a, String ra, DateTime b, String rb) {
      final d = a.compareTo(b);
      return d != 0 ? d : ra.compareTo(rb);
    }
    receipts.sort((a, b) =>
        compare(a.date, a.reference, b.date, b.reference));
    disbursements.sort((a, b) =>
        compare(a.date, a.reference, b.date, b.reference));
    journal.sort((a, b) =>
        compare(a.date, a.reference, b.date, b.reference));

    final ledger = <String, List<LedgerPosting>>{};
    final balances = <String, int>{};
    for (final p in journal) {
      final bal = (balances[p.account] ?? 0) + p.debit - p.credit;
      balances[p.account] = bal;
      ledger.putIfAbsent(p.account, () => []).add(LedgerPosting(p, bal));
    }
    if (adjustmentsCount > 0) {
      warnings.add('$adjustmentsCount PayMongo adjustments/refunds '
          'need supporting documents and classification.');
    }
    if (mismatchCount > 0) {
      warnings.add('$mismatchCount PayMongo transactions fail '
          'gross/fee/net reconciliation.');
    }
    if (grossOverrides > 0) {
      warnings.add('$grossOverrides manually entered PayMongo '
          'gross amounts were not booked again because CSV sales are used.');
    }
    if (hasImported && (month == null || month == 'All time') &&
        (balances[clearing] ?? 0) < 0) {
      warnings.add('PayMongo clearing is negative. Reconcile missing '
          'transactions, opening balance, reserves and bank transfers.');
    }
    if (month != null && month != 'All time' && hasImported) {
      warnings.add('Filtered balances exclude previous periods/opening balances.');
    }
    if (hasImported) {
      warnings.add('PayMongo CSV does not replace official invoices '
          'or bank settlement statements.');
    }
    return AccountingBooks(
      cashReceipts: List.unmodifiable(receipts),
      cashDisbursements: List.unmodifiable(disbursements),
      journal: List.unmodifiable(journal),
      ledger: Map.unmodifiable(ledger),
      warnings: List.unmodifiable(warnings),
      hasImportedPaymongo: hasImported,
    );
  }
}
