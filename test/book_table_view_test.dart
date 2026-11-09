import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/accounting_books.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/book_table_view.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';

final _payment = PayMongoTransaction(
  id: 'pay_compact001', type: 'Payment', status: 'Paid',
  paymentMethod: 'qrph', occurredAt: DateTime(2026, 11, 4),
  grossCentavos: 10000, feeCentavos: -150,
  vatCentavos: -16, netCentavos: 9850,
);
final _payout = BookEntry(
  id: 'payout_compact001', userId: 'local',
  kind: EntryKind.payout, date: DateTime(2026, 11, 5),
  platform: 'PayMongo', description: 'Transfer to BPI',
  category: '', amountCentavos: 9850,
);
final _expense = BookEntry(
  id: 'expense_compact001', userId: 'local',
  kind: EntryKind.expense, date: DateTime(2026, 11, 6),
  platform: '', description: 'Hosting', category: 'Software',
  amountCentavos: 2000,
);

void main() {
  final books = AccountingBooks.fromSources(
    [_payout, _expense], [_payment]);

  test('all four books have concise nonredundant columns', () {
    final expected = [5, 6, 7, 5];
    for (var i = 0; i < 4; i++) {
      final table = BookTableData.build(
        books: books, bookIndex: i, allDates: true);
      expect(table.headers.length, expected[i],
        reason: 'Book ${i + 1} must not be wider than its essential columns');
      expect(table.rows.every((r) => r.length == table.headers.length),
        isTrue);
    }
    final gj = BookTableData.build(
      books: books, bookIndex: 0, allDates: true);
    expect(gj.headers, ['Date','Reference','Account / particulars',
      'Debit (₱)','Credit (₱)']);
    expect(gj.rows.last[1], 'TOTAL');
    expect(gj.rows.last[3], gj.rows.last[4],
      reason: 'General Journal must balance');
  });

  test('cash receipts distinguish sales, bank transfers and clearing', () {
    final view = BookTableData.build(
      books: books, bookIndex: 2, allDates: true);
    expect(view.headers, ['Date','Reference','Particulars',
      'Gross (₱)','Fees (₱)','Bank / cash (₱)','Clearing (₱)']);
    final payment = view.rows.firstWhere((r) => r[1] == _payment.id);
    expect(payment[3], '100.00');
    expect(payment[4], '1.50');
    expect(payment[5], '');
    expect(payment[6], '98.50');
    final payout = view.rows.firstWhere((r) => r[1] == _payout.id);
    expect(payout[3], '', reason: 'Transfer must not be another sale');
    expect(payout[5], '98.50');
    expect(payout[6], '');
    expect(view.rows.last[1], 'TOTAL');
  });

  test('ledger carries beginning balance and shows one signed Dr/Cr column', () {
    final view = BookTableData.build(
      books: books, bookIndex: 1,
      start: DateTime(2026, 11, 6), end: DateTime(2026, 11, 6),
      requestedLedgerAccount: AccountingBooks.bank);
    expect(view.headers.last, 'Balance (₱)');
    expect(view.ledgerAccount, AccountingBooks.bank);
    expect(view.rows.length, 2);
    expect(view.rows.first[1], 'B/F');
    expect(view.rows.first.last, '98.50 Dr');
    expect(view.rows.last[1], _expense.id);
    expect(view.rows.last.last, '78.50 Dr');
    expect(view.summaryRows, contains(0));
  });

  test('voided entries are excluded from ledger opening balance and books', () {
    final view = BookTableData.build(
      books: books, bookIndex: 1,
      start: DateTime(2026, 11, 6),
      end: DateTime(2026, 11, 6),
      voidedReferences: {_payout.id},
      requestedLedgerAccount: AccountingBooks.bank);
    expect(view.rows.length, 1);
    expect(view.rows.first[1], _expense.id);
    expect(view.rows.first.last, '20.00 Cr');
    final disbursements = BookTableData.build(
      books: books, bookIndex: 3, allDates: true,
      verifiedReferences: {_payout.id},
      includeUnverified: false);
    expect(disbursements.rows, isEmpty);
  });

  test('direct manual QR sale lands in bank rather than processor clearing', () {
    final manual = PayMongoTransaction(
      id: 'manual_compact001', type: 'Payment', status: 'Paid',
      source: 'manual', paymentMethod: 'QR Ph',
      occurredAt: DateTime(2026, 11, 8),
      grossCentavos: 5000, feeCentavos: 0,
      vatCentavos: 0, netCentavos: 5000,
      description: 'Review subscription', reference: 'QR-001',
    );
    final directBooks = AccountingBooks.fromSources([], [manual]);
    final table = BookTableData.build(
      books: directBooks, bookIndex: 2, allDates: true);
    expect(table.rows.first[3], '50.00');
    expect(table.rows.first[5], '50.00');
    expect(table.rows.first[6], '');
  });
}
