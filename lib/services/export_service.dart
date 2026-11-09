import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/book_entry.dart';
import '../models/reports.dart';

class ExportService {
  static CellValue t(String s) => TextCellValue(s);
  static CellValue amount(int centavos) => DoubleCellValue(centavos / 100);
  static CellValue dateCell(DateTime d) => DateCellValue(year: d.year, month: d.month, day: d.day);

  static void addSheet(Excel book, String name, List<String> headers,
      Iterable<List<CellValue>> rows, {List<double>? widths}) {
    final sheet = book[name];
    sheet.appendRow(headers.map(t).toList());
    var rowIndex = 1;
    for (final row in rows) {
      sheet.appendRow(row);
      for (var colIndex = 0; colIndex < row.length; colIndex++) {
        if (row[colIndex] is DoubleCellValue) {
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex, rowIndex: rowIndex)).cellStyle =
            CellStyle(numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.00'));
        }
      }
      rowIndex++;
    }
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, widths != null && i < widths.length ? widths[i] : 18);
      final header = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      header.cellStyle = CellStyle(bold: true);
    }
  }

  static Future<void> export(BooksReport report) async {
    if (!report.journalBalanced) throw StateError('Journal does not balance. Export cancelled.');
    final book = Excel.createExcel();
    book.rename('Sheet1', 'READ ME');
    final info = book['READ ME'];
    for (final line in [
      'HYPERION BOOKS — SIMPLE CASH TRACKER',
      'Source: payouts and expenses entered in the app. Every book sheet is computed from these entries.',
      'This is a convenience export, not independently certified BIR books of accounts.',
      'Net platform payouts are not necessarily gross sales. Reconcile invoices, fees, withholding and sale dates for tax reporting.',
      'When Gross is omitted, provisional receipts equal the net payout and deductions are shown as zero.',
      'Dates are transaction/payout dates entered by the user, not verified sales dates.',
      'Deleted entries are excluded. Data remains only in this browser unless exported.',
      'Payout deductions are unclassified; do not assume every deduction is a deductible processing fee.',
    ]) { info.appendRow([t(line)]); }
    info.setColumnWidth(0, 110);

    addSheet(book, 'PAYOUTS', ['Date','Platform','Net payout PHP','Gross if known PHP','Deductions PHP','Note','Entry ID'],
      report.payouts.map((e) => [dateCell(e.date),t(e.platform),amount(e.amountCentavos),
        e.grossCentavos == null ? t('') : amount(e.grossCentavos!),
        amount(e.deductionCentavos),t(e.description),t(e.id)]),
      widths:[17,20,20,24,20,42,40]);
    addSheet(book, 'EXPENSES', ['Date','Category','Description','Amount PHP','Entry ID'],
      report.expenses.map((e) => [dateCell(e.date),t(e.category),t(e.description),
        amount(e.amountCentavos),t(e.id)]), widths:[17,20,48,20,40]);
    addSheet(book, 'CASH RECEIPTS', ['Date','Source','Cash received PHP','Provisional receipts PHP','Deduction PHP','Note'],
      report.payouts.map((e) => [dateCell(e.date),t(e.platform),amount(e.amountCentavos),
        amount(e.receiptsCentavos),amount(e.deductionCentavos),t(e.description)]),
      widths:[18,20,24,26,22,45]);
    addSheet(book, 'CASH DISBURSEMENTS', ['Date','Paid for','Category','Cash paid PHP'],
      report.expenses.map((e) => [dateCell(e.date),t(e.description),t(e.category),amount(e.amountCentavos)]),
      widths:[18,48,23,25]);
    addSheet(book, 'GENERAL JOURNAL', ['Date','Reference','Account','Narration','Debit PHP','Credit PHP'],
      report.journal.map((l) => [dateCell(l.date),t(l.entryId),t(l.account),t(l.narration),
        amount(l.debit),amount(l.credit)]), widths:[18,40,37,54,20,20]);
    final ledgerRows = <List<CellValue>>[];
    for (final account in report.ledger.keys.toList()..sort()) {
      for (final l in report.ledger[account]!) {
        ledgerRows.add([t(account),dateCell(l.journal.date),t(l.journal.entryId),
          t(l.journal.narration),amount(l.journal.debit),amount(l.journal.credit),
          amount(l.debitMinusCreditBalance)]);
      }
    }
    addSheet(book, 'GENERAL LEDGER', ['Account','Date','Reference','Narration','Debit PHP','Credit PHP','Running debit−credit PHP'],
      ledgerRows, widths:[38,17,40,54,20,20,28]);
    addSheet(book, 'MONTHLY SUMMARY', ['Month','Net payouts PHP','Known deductions PHP','Provisional receipts PHP','Expenses PHP','Net cash flow PHP'],
      report.months.map((m) => [t(m.month),amount(m.payoutNet),amount(m.deductions),
        amount(m.receipts),amount(m.expenses),amount(m.netCashFlow)]),
      widths:[18,22,24,29,21,24]);
    final bytes = book.save();
    if (bytes == null) throw StateError('Excel could not generate the workbook');
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Books_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx',
      mimeType: MimeType.custom,
      customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}
