import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/services/paymongo_csv_service.dart';
import 'package:hyperion_books/services/backup_service.dart';
import 'package:hyperion_books/models/book_entry.dart';

const header = 'Transaction ID,Type,Currency,Gross Amount,Fee,VAT,Net Amount,'
  'Status,Transaction Date,Payment Method,Description\n';
const payment = 'pay_test0001,Payment,PHP,50,-0.75,-0.08,49.25,'
  'Paid,11/05/2026 23:12,qrph,"test, with comma"\n';
const adjustment = 'adj_test0001,Adjustment,PHP,-16.4,0,0,-16.4,'
  'Succeeded,11/09/2026 6:34,,"Manual adjustment"\n';

void main() {
  test('CSV imports payments and adjustments by date/time with no VAT double charge', () {
    final parsed = PayMongoCsvService.parse(header + payment + adjustment);
    expect(parsed.ignored, 0);
    expect(parsed.transactions.length, 2);
    expect(parsed.transactions.first.id, 'adj_test0001');
    final sale = parsed.transactions.last;
    expect(sale.grossCentavos, 5000);
    expect(sale.feeCentavos, -75);
    expect(sale.vatCentavos, -8);
    expect(sale.netCentavos, 4925);
    expect(sale.occurredAt, DateTime(2026, 11, 5, 23, 12));
    final sums = PayMongoTotals.fromTransactions(parsed.transactions);
    expect(sums.payments, 1);
    expect(sums.adjustments, 1);
    expect(sums.grossPaymentsCentavos, 5000);
    expect(sums.paymentFeesCentavos, 75);
    expect(sums.paymentVatCentavos, 8);
    expect(sums.netPaymentsCentavos, 4925);
    expect(sums.adjustmentsNetCentavos, -1640);
    expect(sums.activityNetCentavos, 3285);
  });

  test('skips unpaid, duplicate IDs inside CSV rejected, invalid dates rejected', () {
    final unpaid = 'pay_test0002,Payment,PHP,10,0,0,10,'
      'Pending,11/06/2026 12:11,qrph,\n';
    final parsed = PayMongoCsvService.parse(header + payment + unpaid);
    expect(parsed.ignored, 1);
    expect(parsed.transactions.length, 1);
    expect(() => PayMongoCsvService.parse(header + payment + payment), throwsFormatException);
    expect(() => PayMongoCsvService.parse(header +
      payment.replaceAll('11/05/2026', '02/30/2026')), throwsFormatException);
    expect(() => PayMongoCsvService.parse('Date,Amount\n11/05/2026,5'),
      throwsFormatException);
  });

  test('v2 backups include imported transactions, v1 backups still restore', () {
    final imported = PayMongoCsvService.parse(header + payment + adjustment).transactions;
    final entries = <BookEntry>[
      BookEntry(id: 'cash-example', userId: 'local', kind: EntryKind.payout,
        date: DateTime(2026, 11, 8), platform: 'PayMongo',
        description: '', category: '', amountCentavos: 10000),
    ];
    final backup = BackupService.encode(entries, paymongo: imported);
    final decoded = BackupService.decodeFull(backup);
    expect(decoded.entries.length, 1);
    expect(decoded.paymongo.length, 2);
    expect(decoded.paymongo.first.id, imported.first.id);
    expect(decoded.entries.first.amountCentavos, 10000);
    final prior = jsonDecode(backup) as Map<String, dynamic>;
    prior['schema_version'] = 1;
    prior.remove('paymongo');
    final oldRestored = BackupService.decodeFull(jsonEncode(prior));
    expect(oldRestored.entries.length, 1);
    expect(oldRestored.paymongo, isEmpty);
    final tampered = jsonDecode(backup) as Map<String, dynamic>;
    (tampered['paymongo'] as List).add(imported.first.toJson());
    expect(() => BackupService.decodeFull(jsonEncode(tampered)), throwsFormatException);
  });

  test('PayMongo model only stores non-personal transaction fields', () {
    final item = PayMongoCsvService.parse(header + payment).transactions.single;
    expect(item.toJson().keys, isNot(contains('billing_name')));
    expect(item.toJson().keys, isNot(contains('billing_email')));
    final restored = PayMongoTransaction.fromJson(item.toJson());
    expect(restored.id, item.id);
    expect(restored.occurredAt, item.occurredAt);
  });
}
