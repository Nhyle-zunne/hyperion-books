import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/services/sales_import_service.dart';
import 'package:hyperion_books/services/paymongo_import_plan.dart';

void main() {
  const template = SalesImportService.template;

  test('generic sales CSV imports sales, fees and VAT once', () {
    final result = SalesImportService.parseCsv(template);
    expect(result.transactions.length, 1);
    final entry = result.transactions.single;
    expect(entry.id, 'SALE-0001');
    expect(entry.occurredAt, DateTime(2026, 11, 10, 9, 30));
    expect(entry.grossCentavos, 100000);
    expect(entry.feeCentavos, -1500);
    expect(entry.vatCentavos, -161);
    expect(entry.netCentavos, 98500);
    expect(result.ignored, 0);
  });

  test('generic CSV supports minimal columns, quoted references, and unpaid skips', () {
    const csv = 'Reference,Date,Amount,Status,Channel\n'
        'S-000001,2026-11-01 13:30,350.00,Paid,Card\n'
        'S-000002,2026-11-02 16:00,120.00,Pending,QR\n'
        'S-000003,2026-11-03 08:00,200.00,Completed,Cash\n';
    final result = SalesImportService.parseCsv(csv);
    expect(result.transactions.length, 2);
    expect(result.ignored, 1);
    expect(result.transactions.first.paymentMethod, 'Cash');
    expect(result.transactions.first.netCentavos, 20000);
  });

  test('same generic sale cannot duplicate on reimport or file reorder', () {
    final first = SalesImportService.parseCsv(template).transactions;
    final plan = PayMongoImportPlan.prepare(incoming:
      SalesImportService.parseCsv(template).transactions, existing: first);
    expect(plan.newCount, 0);
    expect(plan.alreadyImported, 1);
  });

  test('no unique reference or incorrect fee/VAT math is rejected', () {
    expect(() => SalesImportService.parseCsv(
      'Date,Amount\n2026-11-02 12:00,50.00\n'), throwsFormatException);
    expect(() => SalesImportService.parseCsv(
      'Reference,Date,Amount\n'
      'S-000001,2026-11-01 12:00,100\n'
      'S-000001,2026-11-02 12:00,100\n'), throwsFormatException);
    expect(() => SalesImportService.parseCsv(
      template.replaceFirst('985.00','983.39')), throwsFormatException);
    expect(() => SalesImportService.parseCsv(
      template.replaceFirst('-1.61','-20.00')), throwsFormatException);
  });

  test('legacy processor transaction CSV still imports unchanged', () {
    const legacy = 'Transaction ID,Type,Currency,Gross Amount,Fee,VAT,'
      'Net Amount,Status,Transaction Date,Payment Method\n'
      'pay_synthetic001,Payment,PHP,100.00,-1.50,-0.16,98.50,'
      'Paid,2026-11-03 14:20,qrph\n';
    final result = SalesImportService.parseCsv(legacy);
    expect(result.transactions.single.id, 'pay_synthetic001');
    expect(result.transactions.single.netCentavos, 9850);
  });

  test('XLSX workbook imports date/time, amount and fee values', () {
    final workbook = Excel.createExcel();
    final sheet = workbook['Sheet1'];
    sheet.appendRow([
      TextCellValue('Reference'), TextCellValue('Date'),
      TextCellValue('Gross Amount'), TextCellValue('Fee'),
      TextCellValue('Fee VAT'),
    ]);
    sheet.appendRow([
      TextCellValue('SALE-EX-001'),
      DateTimeCellValue(year: 2026, month: 11, day: 9,
        hour: 14, minute: 20),
      DoubleCellValue(1500.00), DoubleCellValue(-25.00),
      DoubleCellValue(-2.68),
    ]);
    final bytes = workbook.save()!;
    final result = SalesImportService.parseWorkbook(bytes);
    expect(result.transactions.single.id, 'SALE-EX-001');
    expect(result.transactions.single.netCentavos, 147500);
    expect(result.transactions.single.occurredAt, DateTime(2026, 11, 9, 14, 20));
  });
}
