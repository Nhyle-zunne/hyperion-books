import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/accounting_books.dart';
import 'package:hyperion_books/models/business_analytics.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/services/backup_service.dart';

PayMongoTransaction directSale({
  String id = 'manual_direct001', String reference = 'BANK-2026-001',
  int gross = 10000, int fee = -100, int net = 9900,
}) => PayMongoTransaction(
  id: id, type: 'Payment', status: 'Paid', source: 'manual',
  paymentMethod: 'QR Ph', occurredAt: DateTime(2026, 11, 10, 9, 45),
  grossCentavos: gross, feeCentavos: fee, vatCentavos: 0,
  netCentavos: net, reference: reference,
  description: 'OIC NW monthly', customer: 'Sample customer',
  depositAccount: 'Personal bank account', notes: 'Verified QR payment',
);

void main() {
  test('manual QR receipt posts directly to bank and revenue, not clearing', () {
    final sale = directSale();
    final books = AccountingBooks.fromSources([], [sale]);
    expect(books.balanced, isTrue);
    expect(books.accountBalance(AccountingBooks.sales), -10000);
    expect(books.accountBalance(AccountingBooks.bank), 9900);
    expect(books.accountBalance(AccountingBooks.fees), 100);
    expect(books.accountBalance(AccountingBooks.clearing), 0);
    expect(books.hasImportedPaymongo, isFalse);
    expect(books.cashReceipts.single.bankReceived, 9900);
    expect(books.cashReceipts.single.gross, 10000);
    expect(books.journal.where((p) => p.source == 'Manual sale').length, 3);
  });

  test('manual direct sale updates dashboard analytics and cash movement', () {
    final result = BusinessAnalytics.fromSources(
      now: DateTime(2026, 11, 10), days: 7,
      entries: [], paymongo: [directSale()]);
    expect(result.salesCount, 1);
    expect(result.trackedReceipts, 10000);
    expect(result.manualDirectReceipts, 9900);
    expect(result.cashMovement, 9900);
    expect(result.fees, 100);
    expect(result.indicativeResult, 9900);
  });

  test('manual sale survives JSON backup and restore with details', () {
    final source = directSale();
    final backup = BackupService.encode([], paymongo: [source]);
    final loaded = BackupService.decodeFull(backup).paymongo.single;
    expect(loaded.isManual, isTrue);
    expect(loaded.reference, source.reference);
    expect(loaded.description, source.description);
    expect(loaded.customer, source.customer);
    expect(loaded.depositAccount, source.depositAccount);
    expect(loaded.notes, source.notes);
    expect(loaded.netCentavos, 9900);
  });

  test('legacy imported sales without source remain imported', () {
    final json = directSale().toJson()..remove('source');
    json['id'] = 'pay_import001';
    json['description'] = '';
    final loaded = PayMongoTransaction.fromJson(json);
    expect(loaded.isManual, isFalse);
  });

  test('manual receipts cannot declare inconsistent gross and net', () {
    final json = directSale().toJson();
    json['net_centavos'] = 10000;
    expect(() => PayMongoTransaction.fromJson(json),
      throwsA(isA<FormatException>()));
  });
}
