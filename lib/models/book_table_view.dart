import 'package:intl/intl.dart';
import 'accounting_books.dart';
import 'paymongo_transaction.dart';

/// Presentation-only columns for the four BIR-style working books.
/// Source records, postings, and audit references are never altered.
class BookTableData {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> summaryRows;
  final String? ledgerAccount;
  final List<String> ledgerAccounts;

  const BookTableData({
    required this.title,
    required this.headers,
    required this.rows,
    this.summaryRows = const {},
    this.ledgerAccount,
    this.ledgerAccounts = const [],
  });

  static String day(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  static String amount(int centavos) => centavos == 0
      ? '' : NumberFormat('#,##0.00', 'en_PH').format(centavos / 100);
  static String balance(int centavos) => centavos == 0
      ? '0.00' : '${amount(centavos.abs())} ${centavos > 0 ? 'Dr' : 'Cr'}';

  static BookTableData build({
    required AccountingBooks books,
    Iterable<PayMongoTransaction> transactions = const [],
    required int bookIndex,
    DateTime? start,
    DateTime? end,
    bool allDates = false,
    Set<String> voidedReferences = const {},
    Set<String> verifiedReferences = const {},
    bool includeVoided = false,
    bool includeUnverified = true,
    String? requestedLedgerAccount,
  }) {
    bool allowed(String ref) =>
        (includeVoided || !voidedReferences.contains(ref)) &&
        (includeUnverified || verifiedReferences.contains(ref));
    bool within(DateTime when) {
      if (allDates) return true;
      final date = DateTime(when.year, when.month, when.day);
      return (start == null || !date.isBefore(start)) &&
          (end == null || !date.isAfter(end));
    }

    switch (bookIndex) {
      case 0:
        final lines = books.journal.where((p) =>
            allowed(p.reference) && within(p.date)).toList();
        final result = <List<String>>[
          for (final p in lines) [
            day(p.date),
            p.reference,
            '${p.account}  ·  ${p.particulars}',
            amount(p.debit),
            amount(p.credit),
          ],
        ];
        if (lines.isNotEmpty) {
          result.add([
            '', 'TOTAL', '', amount(lines.fold<int>(0, (n, p) => n + p.debit)),
            amount(lines.fold<int>(0, (n, p) => n + p.credit)),
          ]);
        }
        return BookTableData(
          title: 'General Journal',
          headers: const ['Date', 'Reference', 'Account / particulars',
            'Debit (₱)', 'Credit (₱)'],
          rows: result,
          summaryRows: lines.isEmpty ? const {} : {result.length - 1},
        );
      case 1:
        final accounts = books.ledger.keys.toList()..sort();
        final selected = accounts.contains(requestedLedgerAccount)
            ? requestedLedgerAccount
            : accounts.contains(AccountingBooks.bank)
              ? AccountingBooks.bank
              : accounts.isEmpty ? null : accounts.first;
        var running = 0;
        final result = <List<String>>[];
        final records = selected == null
            ? const <LedgerPosting>[]
            : books.ledger[selected] ?? const <LedgerPosting>[];
        for (final line in records) {
          final p = line.posting;
          if (!allowed(p.reference)) {
            continue;
          }
          // Carry included prior-period activity into the running balance.
          if (!allDates && start != null &&
              DateTime(p.date.year, p.date.month, p.date.day).isBefore(start)) {
            running += p.debit - p.credit;
            continue;
          }
          if (!within(p.date)) {
            continue;
          }
          running += p.debit - p.credit;
          result.add([
            day(p.date), p.reference, p.particulars,
            amount(p.debit), amount(p.credit), balance(running),
          ]);
        }
        final opening = !allDates && start != null
            ? records.where((p) => allowed(p.posting.reference) &&
                DateTime(p.posting.date.year, p.posting.date.month,
                  p.posting.date.day).isBefore(start))
                .fold<int>(0, (n, p) => n + p.posting.debit - p.posting.credit)
            : 0;
        if (opening != 0) {
          result.insert(0, [
            start == null ? '' : day(start),
            'B/F', 'Balance brought forward',
            '', '', balance(opening),
          ]);
        }
        return BookTableData(
          title: 'General Ledger',
          headers: const ['Date', 'Reference', 'Particulars',
            'Debit (₱)', 'Credit (₱)', 'Balance (₱)'],
          rows: result,
          ledgerAccounts: accounts,
          ledgerAccount: selected,
          summaryRows: opening == 0 ? const {} : const {0},
        );
      case 2:
        final buyerById = {
          for (final txn in transactions)
            if (txn.customer.trim().isNotEmpty) txn.id: txn.customer.trim(),
        };
        String receiptParticulars(String ref, String particulars) {
          final buyer = buyerById[ref];
          return buyer == null ? particulars : '$particulars · $buyer';
        }
        final lines = books.cashReceipts.where((r) =>
            allowed(r.reference) && within(r.date)).toList();
        final result = <List<String>>[
          for (final r in lines) [
            day(r.date), r.reference,
            receiptParticulars(r.reference, r.particulars),
            amount(r.gross), amount(r.fees), amount(r.bankReceived),
            amount(r.processorNet),
          ],
        ];
        if (lines.isNotEmpty) {
          result.add([
            '', 'TOTAL', '',
            amount(lines.fold<int>(0, (n, r) => n + r.gross)),
            amount(lines.fold<int>(0, (n, r) => n + r.fees)),
            amount(lines.fold<int>(0, (n, r) => n + r.bankReceived)),
            amount(lines.fold<int>(0, (n, r) => n + r.processorNet)),
          ]);
        }
        return BookTableData(
          title: 'Cash Receipts Journal',
          headers: const ['Date', 'Reference', 'Particulars',
            'Gross (₱)', 'Fees (₱)', 'Bank / cash (₱)', 'Clearing (₱)'],
          rows: result,
          summaryRows: lines.isEmpty ? const {} : {result.length - 1},
        );
      default:
        final lines = books.cashDisbursements.where((p) =>
            allowed(p.reference) && within(p.date)).toList();
        final result = <List<String>>[
          for (final p in lines)
            [day(p.date), p.reference, p.particulars,
              p.account, amount(p.amount)],
        ];
        if (lines.isNotEmpty) {
          result.add([
            '', 'TOTAL', '', '',
            amount(lines.fold<int>(0, (n, p) => n + p.amount)),
          ]);
        }
        return BookTableData(
          title: 'Cash Disbursements Journal',
          headers: const ['Date', 'Reference', 'Particulars',
            'Expense account', 'Paid (₱)'],
          rows: result,
          summaryRows: lines.isEmpty ? const {} : {result.length - 1},
        );
    }
  }
}
