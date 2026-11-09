import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/services/expense_csv_service.dart';

void main() {
  const header = 'Reference,Date,Amount,Description,Category\n';
  const row1 = 'EXP-0001,2026-11-03,125.50,"Software, monthly",Software\n';
  const row2 = 'EXP-0002,11/04/2026,950.00,Advertising,Advertising\n';

  test('parses standard and slash dates, quoted commas, integer centavos', () {
    final records = ExpenseCsvService.parse(header + row1 + row2);
    expect(records.length, 2);
    expect(records.first.id, 'expense-import-EXP-0001');
    expect(records.first.amountCentavos, 12550);
    expect(records.first.description, 'Software, monthly');
    expect(records.last.amountCentavos, 95000);
    expect(records.last.date, DateTime(2026, 11, 4));
  });

  test('refuses duplicate references in the same file', () {
    expect(() => ExpenseCsvService.parse(header + row1 + row1),
      throwsFormatException);
  });

  test('requires stable Reference rather than deduping by amount or date', () {
    const copy = 'EXP-0003,2026-11-03,125.50,"Software, monthly",Software\n';
    final imported = ExpenseCsvService.parse(header + row1 + copy);
    expect(imported.map((e) => e.id).toSet().length, 2);
  });

  test('refuses missing columns, invalid dates and malformed values', () {
    expect(() => ExpenseCsvService.parse('Date,Amount\n2026-11-03,100\n'),
      throwsFormatException);
    expect(() => ExpenseCsvService.parse(header +
        row1.replaceFirst('2026-11-03', '2026-02-30')),
      throwsFormatException);
    expect(() => ExpenseCsvService.parse(header +
        row1.replaceFirst('125.50', '-125.50')),
      throwsFormatException);
    expect(() => ExpenseCsvService.parse(header +
        row1.replaceFirst('EXP-0001', 'bad reference with space')),
      throwsFormatException);
  });
}
