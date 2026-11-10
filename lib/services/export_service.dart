import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/reports.dart';
import '../models/accounting_books.dart';
import '../models/business_workspace.dart';
import '../models/paymongo_transaction.dart';

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

  static Future<void> export(BooksReport report,
      {Iterable<PayMongoTransaction> paymongo = const [],
       BusinessWorkspace workspace = const BusinessWorkspace()}) async {
    if (!report.journalBalanced) {
      throw StateError('Manual journal does not balance. Export cancelled.');
    }
    final imported = paymongo.toList()
      ..sort((a, b) {
        final order = a.occurredAt.compareTo(b.occurredAt);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final books = AccountingBooks.fromSources(
      [...report.payouts, ...report.expenses], imported);
    final buyers = {for (final t in imported) t.id: t.customer.trim()};
    if (!books.balanced) {
      throw StateError('Combined accounting journal is not balanced. Export cancelled.');
    }
    CellValue moneyOrBlank(int value) => value == 0 ? t('') : amount(value);
    final book = Excel.createExcel();
    book.rename('Sheet1', 'READ ME');
    final info = book['READ ME'];
    for (final line in [
      'HYPERION BOOKS — ACCOUNTING WORKING PAPERS',
      'Four separate journals/ledgers: Cash Receipts Journal, Cash Disbursements Journal, General Journal and General Ledger.',
      'This Excel workbook is NOT a BIR-authorized computerized book or approved loose-leaf book. Confirm registration and approval requirements with your RDO.',
      'Source records: imported or manual sales, bank payouts and expenses. Dates and amounts require reconciliation with invoices and bank statements.',
      'Imported paid sale: Debit sales clearing (net), Debit processing fees (VAT already included), Credit provisional imported sales (gross).',
      'PayMongo bank payout (entered manually): Debit Cash/Bank, Credit PayMongo clearing; this is NOT a second sale.',
      'Fees include their VAT component; do not subtract or recognize VAT twice. Input VAT treatment depends on taxpayer status and documentation.',
      'Adjustments/refunds and gross/fee/net differences go into accounts labeled REVIEW until supporting documents justify their classification.',
      'Google Play payouts and PayMongo payouts without source transactions remain provisional/unmatched, not verified gross tax receipts.',
      'The on-screen ledger carries earlier-period activity into the displayed balance. Verify opening balances and exclude voided references consistently.',
      'The Cash Receipts Journal separates gross imported sales, net settlement clearing and actual bank receipts. Do not sum these distinct columns as revenue.',
      'The General Journal includes all postings consolidated; do not also post the specialized journal sheets a second time.',
      'The reports are not a substitute for a registered set of books or verified invoices, official supporting documents and tax returns.',
      'Sales transaction customer name/email/phone/address/TIN and invoice drafts are personal data. Protect this unencrypted workbook and share only with authorized recipients.',
      'Compliance reminders are user-set dates and do not validate filing deadlines or produce tax returns.',
      'BIR RMC 65-2025: https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2065-2025%20Digest.pdf',
      'BIR RMC 4-2026: https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%204-2026.pdf',
      'BIR RR 7-2024: https://bir-cdn.bir.gov.ph/BIR/pdf/RR%20No.%207-%202024.pdf',
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
    // One concise format per book, aligned with the on-screen account view.
    // Fees, processor clearing and bank cash remain separate to avoid
    // treating transfers as additional revenue.
    addSheet(book, 'CASH RECEIPTS JOURNAL',
      ['Date','Reference','Particulars','Gross PHP','Fees PHP',
       'Bank / cash PHP','Clearing PHP'],
      books.cashReceipts.map((e) => [
        dateCell(e.date), t(e.reference), t(buyers[e.reference] == null ||
          buyers[e.reference]!.isEmpty ? e.particulars
          : '${e.particulars} · ${buyers[e.reference]}'),
        moneyOrBlank(e.gross), moneyOrBlank(e.fees),
        moneyOrBlank(e.bankReceived), moneyOrBlank(e.processorNet),
      ]),
      widths: [18,36,55,20,20,23,23]);
    addSheet(book, 'CASH DISBURSEMENTS JOURNAL',
      ['Date','Reference','Particulars / payee',
       'Expense account','Paid PHP'],
      books.cashDisbursements.map((e) => [
        dateCell(e.date), t(e.reference), t(e.particulars),
        t(e.account), amount(e.amount),
      ]), widths: [18,38,54,40,22]);
    addSheet(book, 'GENERAL JOURNAL',
      ['Date','Reference','Account / particulars','Debit PHP','Credit PHP'],
      books.journal.map((e) => [
        dateCell(e.date), t(e.reference),
        t('${e.account} · ${e.particulars}'),
        moneyOrBlank(e.debit), moneyOrBlank(e.credit),
      ]), widths: [18,39,80,22,22]);
    final ledgerRows = <List<CellValue>>[];
    for (final account in books.ledger.keys.toList()..sort()) {
      for (final line in books.ledger[account]!) {
        ledgerRows.add([
          t(account), dateCell(line.posting.date), t(line.posting.reference),
          t(line.posting.particulars),
          moneyOrBlank(line.posting.debit), moneyOrBlank(line.posting.credit),
          amount(line.signedBalance),
        ]);
      }
    }
    addSheet(book, 'GENERAL LEDGER',
      ['Account','Date','Reference','Particulars',
       'Debit PHP','Credit PHP','Balance PHP (+Dr / -Cr)'],
      ledgerRows, widths: [40,18,38,55,22,22,28]);
    final monthKeys = <String>{
      ...report.months.map((m) => m.month),
      ...imported.map((t) => t.month),
    }.toList()..sort();
    final byMonth = {for (final m in report.months) m.month: m};
    addSheet(book, 'MONTHLY SUMMARY',
      ['Month','Recorded gross sales PHP','Processing fees PHP',
       'Net sales payments PHP','Adjustments/refunds PHP',
       'Manual bank payouts PHP','Manual expenses PHP',
       'Payouts + direct sales - expenses PHP'],
      monthKeys.map((key) {
        final m = byMonth[key];
        final p = PayMongoTotals.fromTransactions(
          imported.where((t) => t.month == key));
        final directCash = imported.where((t) =>
            t.month == key && t.isManual && t.isPayment)
            .fold<int>(0, (n, t) => n + t.netCentavos);
        return [
          t(key),amount(p.grossPaymentsCentavos),
          amount(p.paymentFeesCentavos),amount(p.netPaymentsCentavos),
          amount(p.adjustmentsNetCentavos),amount(m?.payoutNet ?? 0),
          amount(m?.expenses ?? 0),
          amount((m?.netCashFlow ?? 0) + directCash),
        ];
      }), widths: [17,28,23,29,26,29,26,29]);
    addSheet(book, 'RECONCILIATION NOTES',
      ['Review item / warning'],
      books.warnings.map((warning) => [t(warning)]),
      widths: [120]);
    addSheet(book, 'SALES TRANSACTIONS',
      ['Date / time', 'Record ID', 'Source', 'Payment reference',
       'Product / service', 'Customer name', 'Customer email',
       'Customer phone', 'Buyer address', 'Buyer TIN', 'Received into',
       'Type', 'Status', 'Gross PHP', 'Fee PHP',
       'Fee VAT portion PHP', 'Net PHP', 'Method', 'Notes'],
      imported.map((e) => [
        t(DateFormat('yyyy-MM-dd HH:mm').format(e.occurredAt)), t(e.id),
        t(e.isManual ? 'Manual direct payment' : 'CSV / Excel import'),
        t(e.reference), t(e.description), t(e.customer),
        t(e.customerEmail), t(e.customerPhone),
        t(e.customerAddress), t(e.customerTin), t(e.depositAccount),
        t(e.type), t(e.status), amount(e.grossCentavos),
        amount(e.feeCentavos), amount(e.vatCentavos),
        amount(e.netCentavos), t(e.paymentMethod), t(e.notes),
      ]),
      widths: [23, 41, 24, 27, 35, 27, 32, 24, 38, 23, 27, 17, 19, 20, 22, 23, 20, 18, 38]);
    addSheet(book, 'BUSINESS PROFILE',
      ['Field', 'Value'], [
        [t('Business name'), t(workspace.businessName)],
        [t('TIN (not verified)'), t(workspace.businessTin)],
        [t('Business address'), t(workspace.businessAddress)],
        [t('Registration status'), t(workspace.registrationStatus)],
        [t('Tax method (user selected)'), t(workspace.taxStatus)],
        [t('Private notes'), t(workspace.notes)],
      ], widths: [34, 90]);
    addSheet(book, 'MASTER LISTS',
      ['List','Name','Email','Phone','Address','TIN (unverified)',
       'Notes','Reference price PHP'],
      workspace.masters.map((item) => [
        t(item.kind), t(item.name), t(item.email), t(item.phone),
        t(item.address), t(item.tin), t(item.details),
        item.priceCentavos == null ? t('') : amount(item.priceCentavos!),
      ]), widths: [23,40,32,22,48,25,68,26]);
    addSheet(book, 'COMPLIANCE TASKS',
      ['Due date', 'Task', 'Completed', 'Notes'],
      workspace.reminders.map((item) => [
        dateCell(item.dueDate), t(item.title),
        t(item.completed ? 'Yes' : 'No'), t(item.notes),
      ]), widths: [19, 45, 20, 85]);
    addSheet(book, 'OPERATING REGISTERS',
      ['Type','Date','Reference','Description','Counterparty',
       'Status','Amount PHP','Notes'],
      workspace.operations.map((item) => [
        t(item.kind),dateCell(item.date),t(item.reference),
        t(item.description),t(item.counterparty),t(item.status),
        amount(item.amountCentavos),t(item.notes),
      ]), widths: [20,18,38,55,44,20,23,60]);
    addSheet(book, 'TAX TRACKING RECORDS',
      ['Kind','Date','Due Date','Period','Name / form','Reference','Status',
       'Direction','Amount PHP','Notes'],
      workspace.taxRecords.map((item) => [
        t(item.kind),dateCell(item.date),
        item.dueDate == null ? t('') : dateCell(item.dueDate!),
        t(item.period),t(item.name),
        t(item.reference),t(item.status),t(item.direction),
        amount(item.amountCentavos),t(item.notes),
      ]), widths: [17,19,19,17,45,39,20,19,20,55]);
    final bytes = book.save();
    if (bytes == null) throw StateError('Excel could not generate the workbook');
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Books_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx',
      mimeType: MimeType.custom,
      customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
  /// Exports exactly the currently selected book, period and visible columns.
  /// Monetary cells are numeric in Excel; the HTML/Flutter UI only formats them.
  static Future<void> exportBookTable(
    String title, List<String> headers, List<List<String>> rows, {
    required String period,
    required String businessName,
    String businessTin = '',
    String businessAddress = '',
  }) async {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'READ ME');
    final info = workbook['READ ME'];
    for (final note in [
      'HYPERION BOOKS — DRAFT ACCOUNTING REPORT',
      'Business: ${businessName.trim().isEmpty ? "Not specified" : businessName}',
      'TIN (user entered): $businessTin',
      'Business address: $businessAddress',
      'Book: $title',
      'Covered period: $period',
      'Transactions are derived from local entries and imported or manual sales.',
      'These are not BIR-registered computerized books or proof of tax filing.',
      'The displayed ledger running balances include prior-period transactions.',
      'Preserve invoices and bank statements; reconcile all provisional entries.',
    ]) { info.appendRow([t(note)]); }
    info.setColumnWidth(0, 110);
    final monetary = headers.map((header) =>
        header.contains('(₱)') || header.endsWith(' PHP')).toList();
    CellValue reportCell(String raw, bool isMoney) {
      if (!isMoney || raw.trim().isEmpty) {
        return t(raw);
      }
      final creditSide = raw.trim().endsWith(' Cr');
      final cleaned = raw.replaceAll('₱', '').replaceAll(',', '')
          .replaceAll(RegExp(r'\s+(Dr|Cr)$'), '').trim();
      final value = double.tryParse(cleaned);
      if (value == null) {
        return t(raw);
      }
      return DoubleCellValue(creditSide ? -value : value);
    }
    final reportRows = rows.map((row) => [
      for (var i = 0; i < headers.length; i++)
        reportCell(row[i], monetary[i]),
    ]);
    final sheetName = title.split(' - ').first.toUpperCase();
    final widths = switch (sheetName) {
      'GENERAL JOURNAL' => <double>[18.0, 37, 75, 22, 22],
      'GENERAL LEDGER' => <double>[18.0, 37, 58, 22, 22, 25],
      'CASH RECEIPTS JOURNAL' => <double>[18.0, 37, 58, 22, 22, 23, 23],
      'CASH DISBURSEMENTS JOURNAL' => <double>[18.0, 37, 57, 42, 23],
      _ => List<double>.filled(headers.length, 24),
    };
    addSheet(workbook, sheetName, headers, reportRows, widths: widths);
    final bytes = workbook.save();
    if (bytes == null) throw StateError('Excel could not generate the workbook');
    await FileSaver.instance.saveFile(
      name: 'Hyperion_Books_${DateFormat('yyyyMMdd').format(DateTime.now())}_${title.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}',
      bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx',
      mimeType: MimeType.custom,
      customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

}
