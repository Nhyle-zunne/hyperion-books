import 'book_entry.dart';

class JournalLine {
  final String entryId;
  final DateTime date;
  final String account;
  final String narration;
  final int debit;
  final int credit;

  const JournalLine(this.entryId, this.date, this.account, this.narration, this.debit, this.credit);
}

class MonthSummary {
  final String month;
  final int payoutNet;
  final int deductions;
  final int receipts;
  final int expenses;

  const MonthSummary(this.month, this.payoutNet, this.deductions, this.receipts, this.expenses);
  int get netCashFlow => payoutNet - expenses;
}

class LedgerLine {
  final JournalLine journal;
  final int debitMinusCreditBalance;
  const LedgerLine(this.journal, this.debitMinusCreditBalance);
}

class BooksReport {
  final List<BookEntry> payouts;
  final List<BookEntry> expenses;
  final List<JournalLine> journal;
  final Map<String, List<LedgerLine>> ledger;
  final List<MonthSummary> months;
  const BooksReport({required this.payouts, required this.expenses,
    required this.journal, required this.ledger, required this.months});

  int get netPayouts => payouts.fold(0, (sum, e) => sum + e.amountCentavos);
  int get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amountCentavos);
  int get netCashMovement => netPayouts - totalExpenses;
  bool get journalBalanced =>
      journal.fold<int>(0, (s, l) => s + l.debit) ==
      journal.fold<int>(0, (s, l) => s + l.credit);

  factory BooksReport.fromEntries(Iterable<BookEntry> entries) {
    final items = entries.where((e) => !e.deleted).toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final payouts = items.where((e) => e.kind == EntryKind.payout).toList();
    final expenses = items.where((e) => e.kind == EntryKind.expense).toList();
    final journal = <JournalLine>[];
    final monthData = <String, List<int>>{};

    for (final e in items) {
      final key = e.dateKey.substring(0, 7);
      final totals = monthData.putIfAbsent(key, () => [0, 0, 0, 0]);
      if (e.kind == EntryKind.payout) {
        final narration = '${e.platform} payout${e.description.isEmpty ? '' : ' — ${e.description}'}';
        totals[0] += e.amountCentavos;
        totals[1] += e.deductionCentavos;
        totals[2] += e.receiptsCentavos;
        journal.add(JournalLine(e.id, e.date, 'Cash / bank', narration, e.amountCentavos, 0));
        if (e.deductionCentavos > 0) {
          journal.add(JournalLine(e.id, e.date, 'Platform deductions (unclassified)', narration, e.deductionCentavos, 0));
        }
        journal.add(JournalLine(e.id, e.date, 'Payout receipts (provisional)', narration, 0, e.receiptsCentavos));
      } else {
        totals[3] += e.amountCentavos;
        final narration = e.description.isEmpty ? 'Expense' : e.description;
        journal.add(JournalLine(e.id, e.date, 'Expense: ${e.category}', narration, e.amountCentavos, 0));
        journal.add(JournalLine(e.id, e.date, 'Cash / bank', narration, 0, e.amountCentavos));
      }
    }

    final ledger = <String, List<LedgerLine>>{};
    final balances = <String, int>{};
    for (final line in journal) {
      final balance = (balances[line.account] ?? 0) + line.debit - line.credit;
      balances[line.account] = balance;
      ledger.putIfAbsent(line.account, () => []).add(LedgerLine(line, balance));
    }
    final monthKeys = monthData.keys.toList()..sort((a, b) => b.compareTo(a));
    final months = monthKeys.map((k) {
      final v = monthData[k]!;
      return MonthSummary(k, v[0], v[1], v[2], v[3]);
    }).toList();
    return BooksReport(payouts: payouts, expenses: expenses,
      journal: journal, ledger: ledger, months: months);
  }
}
