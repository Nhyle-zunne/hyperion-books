import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/accounting_books.dart';
import 'package:hyperion_books/models/book_table_view.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/services/backup_service.dart';
import 'package:hyperion_books/services/paymongo_csv_service.dart';
import 'package:hyperion_books/services/sales_import_service.dart';
import 'package:hyperion_books/services/paymongo_import_plan.dart';

const paymongoWithCustomer =
    'Transaction ID,Type,Currency,Gross Amount,Fee,VAT,'
    'Net Amount,Status,Transaction Date,Payment Method,Customer Name,'
    'Customer Email,Customer Mobile Number,Billing Address,Buyer TIN,Card Last 4\n'
    'pay_customer001,Payment,PHP,150,-2,-0.21,148,Paid,'
    '2026-11-09 12:30,qrph,"Sample, Customer",'
    'sample@example.test,+639001234567,"Cebu City, PH",123-456-789,9999\n';

void main() {
  test('PayMongo parser keeps only relevant buyer identity and contact details', () {
    final row = PayMongoCsvService.parse(paymongoWithCustomer).transactions.single;
    expect(row.customer, 'Sample, Customer');
    expect(row.customerEmail, 'sample@example.test');
    expect(row.customerPhone, '+639001234567');
    expect(row.customerAddress, 'Cebu City, PH');
    expect(row.customerTin, '123-456-789');
    expect(row.grossCentavos, 15000);
    expect(row.feeCentavos, -200);
    expect(row.netCentavos, 14800);
    expect(row.toJson().toString(), isNot(contains('9999')),
      reason: 'Never keep unrelated card fields from payment CSV exports');
  });

  test('generic sales CSV and template also retain customer profile', () {
    final row = SalesImportService.parseCsv(SalesImportService.template)
        .transactions.single;
    expect(row.customer, 'Sample Customer');
    expect(row.customerEmail, 'buyer@example.test');
    expect(row.customerPhone, '+63-900-000-0000');
    expect(row.customerTin, isEmpty);
  });

  test('old imported sale can gain missing buyer fields without changing amounts', () {
    final fresh = PayMongoCsvService.parse(paymongoWithCustomer)
        .transactions.single;
    final json = fresh.toJson()
      ..remove('customer')
      ..remove('customer_email')
      ..remove('customer_phone')
      ..remove('customer_address')
      ..remove('customer_tin');
    final existing = PayMongoTransaction.fromJson(json);
    final plan = PayMongoImportPlan.prepare(
      incoming: [fresh], existing: [existing]);
    expect(plan.newCount, 0);
    expect(plan.alreadyImported, 1);
    expect(plan.customerDetailsToEnrich, 1);
    final enriched = existing.withMissingCustomerDetails(fresh);
    expect(enriched.customerEmail, fresh.customerEmail);
    expect(enriched.grossCentavos, existing.grossCentavos);
    expect(enriched.feeCentavos, existing.feeCentavos);
    expect(enriched.netCentavos, existing.netCentavos);
    expect(enriched.canEnrichFrom(fresh), false,
      reason: 'Repeated enrichment must be idempotent');
    final tampered = PayMongoTransaction.fromJson(
      fresh.toJson()..['gross_centavos'] = fresh.grossCentavos + 100);
    expect(existing.canEnrichFrom(tampered), false,
      reason: 'Conflicting accounting values must block enrichment');
  });

  test('buyer name stays within cash receipt particulars, not extra book columns', () {
    final paid = PayMongoCsvService.parse(paymongoWithCustomer)
        .transactions.single;
    final books = AccountingBooks.fromSources([], [paid]);
    final cash = BookTableData.build(
      books: books, bookIndex: 2, allDates: true, transactions: [paid]);
    expect(cash.headers.length, 7);
    expect(cash.rows.first[2], contains('Sample, Customer'));
    expect(cash.rows.first[2], isNot(contains('sample@example.test')));
    final journal = BookTableData.build(
      books: books, bookIndex: 0, allDates: true);
    expect(journal.headers.length, 5);
    expect(journal.rows.join(' '), isNot(contains('sample@example.test')));
  });

  test('backups roundtrip private buyer and draft invoice details', () {
    final row = PayMongoCsvService.parse(paymongoWithCustomer)
        .transactions.single;
    final invoice = TaxRecord(
      id: 'invoice-prep-001', kind: 'Invoice', name: row.customer,
      reference: '', date: DateTime(2026, 11, 9),
      sourceSaleId: row.id, buyerEmail: row.customerEmail,
      buyerPhone: row.customerPhone, buyerAddress: row.customerAddress,
      buyerTin: row.customerTin, itemDescription: 'Review subscription',
      amountCentavos: 15000, cwtCentavos: 0,
    );
    final master = BusinessListItem(
      id: 'customer-master-001', kind: 'Customer', name: row.customer,
      email: row.customerEmail, phone: row.customerPhone,
      tin: row.customerTin, address: row.customerAddress,
    );
    final backup = BackupService.encode([],
      paymongo: [row], workspace: BusinessWorkspace(
        masters: [master], taxRecords: [invoice]));
    final restored = BackupService.decodeFull(backup);
    expect(restored.paymongo.single.customerEmail, row.customerEmail);
    expect(restored.workspace.masters.single.phone, row.customerPhone);
    expect(restored.workspace.taxRecords.single.sourceSaleId, row.id);
    expect(restored.workspace.taxRecords.single.buyerTin, row.customerTin);
    expect(restored.workspace.taxRecords.single.itemDescription,
      'Review subscription');
  });

  test('older data without optional fields remains valid', () {
    final json = TaxRecord(
      id: 'old-invoice001', kind: 'Invoice', name: 'Sample',
      reference: '', date: DateTime(2026, 11, 1)).toJson()
      ..remove('buyer_email')
      ..remove('buyer_phone')
      ..remove('buyer_address')
      ..remove('buyer_tin')
      ..remove('source_sale_id')
      ..remove('item_description')
      ..remove('cwt_centavos');
    expect(TaxRecord.fromJson(json).buyerEmail, isEmpty);
  });
}
