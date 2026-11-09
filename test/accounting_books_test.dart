import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/accounting_books.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';

PayMongoTransaction payment({
  String id = 'pay_sample001',
  int gross = 10000,
  int fee = -150,
  int net = 9850,
  DateTime? date,
}) => PayMongoTransaction(
  id: id, type: 'Payment', status: 'Paid', paymentMethod: 'qrph',
  occurredAt: date ?? DateTime(2026, 11, 4, 13, 51),
  grossCentavos: gross, feeCentavos: fee, vatCentavos: -16,
  netCentavos: net,
);

BookEntry manual({
  required String id, required EntryKind kind, required int amount,
  String platform = 'PayMongo', int? gross, DateTime? date,
}) => BookEntry(
  id: id, userId: 'local', kind: kind,
  date: date ?? DateTime(2026, 11, 5),
  platform: kind == EntryKind.payout ? platform : '',
  description: kind == EntryKind.expense ? 'Hosting fee' : '',
  category: kind == EntryKind.expense ? 'Hosting' : '',
  amountCentavos: amount, grossCentavos: gross,
);

void main() {
  test('imported sale, subsequent bank transfer and expense create four books '
      'without double-counting revenue', () {
    final books = AccountingBooks.fromSources([
      manual(id: 'bank001', kind: EntryKind.payout, amount: 9850),
      manual(id: 'expense001', kind: EntryKind.expense, amount: 2000),
    ], [payment()]);
    expect(books.balanced, isTrue);
    expect(books.cashReceipts.length, 2);
    expect(books.cashDisbursements.length, 1);
    expect(books.cashReceipts.singleWhere((r) => r.bankTransfer).gross, 0);
    expect(books.cashReceipts.singleWhere((r) => !r.bankTransfer).gross, 10000);
    expect(books.accountBalance(AccountingBooks.sales), -10000);
    expect(books.accountBalance(AccountingBooks.fees), 150);
    expect(books.accountBalance(AccountingBooks.clearing), 0);
    expect(books.accountBalance(AccountingBooks.bank), 7850);
    expect(books.journal.where((p) =>
      p.account == AccountingBooks.sales).length, 1);
    expect(books.ledger.containsKey(AccountingBooks.sales), isTrue);
    expect(books.ledger[AccountingBooks.bank]!.last.signedBalance, 7850);
  });

  test('CSV import alone populates cash receipts, journal and ledger '
      'without inventing a bank deposit', () {
    final books = AccountingBooks.fromSources([], [payment()]);
    expect(books.balanced, isTrue);
    expect(books.cashReceipts.length, 1);
    expect(books.cashReceipts.single.bankReceived, 0);
    expect(books.cashReceipts.single.processorNet, 9850);
    expect(books.accountBalance(AccountingBooks.bank), 0);
    expect(books.accountBalance(AccountingBooks.clearing), 9850);
    expect(books.journal.length, 3);
  });

  test('partial-month filter never reclassifies a later payout as a sale', () {
    final oldSale = payment(date: DateTime(2026, 10, 29));
    final laterPayout = manual(id: 'bank002',
      kind: EntryKind.payout, amount: 9850, date: DateTime(2026, 11, 7));
    final filtered = AccountingBooks.fromSources(
      [laterPayout], [oldSale], month: '2026-11');
    expect(filtered.balanced, isTrue);
    expect(filtered.journal.length, 2);
    expect(filtered.accountBalance(AccountingBooks.sales), 0);
    expect(filtered.accountBalance(AccountingBooks.bank), 9850);
    expect(filtered.accountBalance(AccountingBooks.clearing), -9850);
  });

  test('adjustments and refunds are review accounts, not additional sales', () {
    final adjustment = PayMongoTransaction(
      id: 'adj_example001', type: 'Adjustment',
      status: 'Succeeded', paymentMethod: 'Not applicable',
      occurredAt: DateTime(2026, 11, 4, 6, 49),
      grossCentavos: -1640, feeCentavos: 0,
      vatCentavos: 0, netCentavos: -1640);
    final books = AccountingBooks.fromSources([], [payment(), adjustment]);
    expect(books.balanced, isTrue);
    expect(books.accountBalance(AccountingBooks.sales), -10000);
    expect(books.accountBalance(AccountingBooks.clearing), 8210);
    expect(books.accountBalance(AccountingBooks.adjustments), 1640);
    expect(books.warnings.any((w) => w.contains('classification')), isTrue);
  });

  test('gross manual PayMongo payout is not booked as revenue after CSV import', () {
    final books = AccountingBooks.fromSources([
      manual(id: 'bank003', kind: EntryKind.payout,
        amount: 9850, gross: 10000),
    ], [payment()]);
    expect(books.balanced, isTrue);
    expect(books.accountBalance(AccountingBooks.sales), -10000);
    expect(books.warnings.any((w) => w.contains('gross amounts')), isTrue);
  });

  test('manual-only payout remains provisional rather than verified CSV sales', () {
    final books = AccountingBooks.fromSources([
      manual(id: 'bank004', kind: EntryKind.payout, amount: 9850),
    ], []);
    expect(books.balanced, isTrue);
    expect(books.accountBalance(AccountingBooks.unmatched), -9850);
    expect(books.accountBalance(AccountingBooks.sales), 0);
    expect(books.cashReceipts.single.provisional, isTrue);
  });
}
