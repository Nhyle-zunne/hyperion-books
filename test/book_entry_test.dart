import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/reports.dart';

BookEntry sample({required String id, required EntryKind kind, required int amount,
  int? gross, String platform = 'PayMongo', bool deleted = false,
  DateTime? date}) => BookEntry(
    id: id, userId: 'test-user', kind: kind,
    date: date ?? DateTime(2026, 11, 9),
    platform: kind == EntryKind.payout ? platform : '',
    description: kind == EntryKind.expense ? 'Website hosting' : '',
    category: 'Software', amountCentavos: amount,
    grossCentavos: gross, deleted: deleted,
  );

void main() {
  test('money input uses integer centavos and rejects excess decimals', () {
    expect(parsePesos('₱ 8,663.87'), 866387);
    expect(parsePesos('700'), 70000);
    expect(parsePesos('0.5'), 50);
    expect(parsePesos('2.159'), isNull);
    expect(parsePesos('-100'), isNull);
  });

  test('a net payout and an expense create balanced double-entry journals', () {
    final report = BooksReport.fromEntries([
      sample(id: 'p1', kind: EntryKind.payout, amount: 454755),
      sample(id: 'e1', kind: EntryKind.expense, amount: 100000),
    ]);
    expect(report.netPayouts, 454755);
    expect(report.totalExpenses, 100000);
    expect(report.netCashMovement, 354755);
    expect(report.journal.length, 4);
    expect(report.journalBalanced, isTrue);
    expect(report.ledger['Cash / bank']!.last.debitMinusCreditBalance, 354755);
  });

  test('optional gross records an explicit unclassified deduction', () {
    final report = BooksReport.fromEntries([
      sample(id: 'p1', kind: EntryKind.payout, amount: 97000, gross: 100000),
    ]);
    expect(report.journal.length, 3);
    expect(report.journalBalanced, isTrue);
    expect(report.journal.where((j) => j.account.contains('deductions')).single.debit, 3000);
    expect(report.months.single.receipts, 100000);
  });

  test('deleted entries are excluded, and months are independently grouped', () {
    final report = BooksReport.fromEntries([
      sample(id: 'p1', kind: EntryKind.payout, amount: 20000),
      sample(id: 'e1', kind: EntryKind.expense, amount: 5000, deleted: true),
      sample(id: 'p2', kind: EntryKind.payout, amount: 30000, date: DateTime(2026, 12, 1)),
    ]);
    expect(report.expenses, isEmpty);
    expect(report.months.length, 2);
    expect(report.months.first.month, '2026-12');
    expect(report.journalBalanced, isTrue);
  });

  test('editing an entry marks it dirty and increments local edit sequence', () {
    final old = sample(id:'p1',kind:EntryKind.payout,amount:10000);
    final edited = old.markEdited(date:DateTime(2026,11,10), platform:'Google Play',
      description:'Monthly payout',category:'',amountCentavos:20000);
    expect(edited.id, old.id);
    expect(edited.editSequence, old.editSequence + 1);
    expect(edited.dirty, isTrue);
    expect(edited.platform, 'Google Play');
  });
}
