import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/models/tax_period_summary.dart';
import 'package:hyperion_books/services/backup_service.dart';

void main() {
  test('tax record roundtrip remains private within v3 backup workspace', () {
    final record = TaxRecord(
      id: 'certificate-1', kind: '2307',
      name: 'Customer A', reference: 'CERT-2026-01',
      date: DateTime(2026, 10, 15),
      period: '2026-Q3', status: 'Received', direction: 'Incoming',
      notes: 'Paper certificate kept', amountCentavos: 1700,
    );
    final json = BackupService.encode([], workspace: BusinessWorkspace(
      taxRecords: [record]));
    final restored = BackupService.decodeFull(json).workspace.taxRecords.single;
    expect(restored.name, 'Customer A');
    expect(restored.amountCentavos, 1700);
    expect(restored.reference, 'CERT-2026-01');
    expect(restored.date, DateTime(2026, 10, 15));
  });

  test('existing v3 workspace backups without tax records remain valid', () {
    final json = BackupService.encode([], workspace: const BusinessWorkspace(
      businessName: 'Example'));
    final raw = jsonDecode(json) as Map<String, dynamic>;
    (raw['workspace'] as Map<String, dynamic>).remove('tax_records');
    expect(BackupService.decodeFull(jsonEncode(raw)).workspace.taxRecords,
      isEmpty);
  });

  test('rejects duplicate and invalid tax certificate records', () {
    final item = TaxRecord(id: '1', kind: 'Invoice', name: 'Buyer',
      reference: 'INV-1', date: DateTime(2026, 11, 2));
    final raw = jsonDecode(BackupService.encode([],
      workspace: BusinessWorkspace(taxRecords: [item])))
      as Map<String, dynamic>;
    final list = (raw['workspace'] as Map<String, dynamic>)['tax_records'] as List;
    list.add(Map<String, dynamic>.from(list.first as Map));
    expect(() => BackupService.decodeFull(jsonEncode(raw)), throwsFormatException);
    list.removeLast();
    (list.first as Map<String, dynamic>)['amount_centavos'] = -10;
    expect(() => BackupService.decodeFull(jsonEncode(raw)), throwsFormatException);
  });

  test('manual verification and report-only void flags persist in v3 backups', () {
    const workspace = BusinessWorkspace(
      verifiedReferences: ['pay_accepted001'],
      voidedReferences: ['pay_void001'],
    );
    final encoded = BackupService.encode([], workspace: workspace);
    final stored = BackupService.decodeFull(encoded).workspace;
    expect(stored.verifiedReferences, ['pay_accepted001']);
    expect(stored.voidedReferences, ['pay_void001']);
    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    final scope = raw['workspace'] as Map<String, dynamic>;
    scope['verified_references'] = ['pay_accepted001', 'pay_accepted001'];
    expect(() => BackupService.decodeFull(jsonEncode(raw)), throwsFormatException);
  });

  test('time window counts original PayMongo payment, not its bank payout twice', () {
    final payment = PayMongoTransaction(id: 'pay_tax001', type: 'Payment',
      status: 'Paid', paymentMethod: 'qrph',
      occurredAt: DateTime(2026, 11, 2, 9, 40),
      grossCentavos: 10000, feeCentavos: -150,
      vatCentavos: -16, netCentavos: 9850);
    final bank = BookEntry(id: 'bank-1', userId: 'local',
      kind: EntryKind.payout, date: DateTime(2026, 11, 4),
      platform: 'PayMongo', description: '', category: '',
      amountCentavos: 9850);
    final expense = BookEntry(id: 'expense-1', userId: 'local',
      kind: EntryKind.expense, date: DateTime(2026, 11, 6),
      platform: '', description: 'Subscription', category: 'Software',
      amountCentavos: 2000);
    final s = TaxPeriodSummary.between(entries: [bank, expense],
      transactions: [payment], first: DateTime(2026, 11),
      last: DateTime(2026, 11, 30));
    expect(s.paymongoGross, 10000);
    expect(s.trackedReceipts, 10000);
    expect(s.knownCosts, 2150);
    expect(s.bankDeposits, 9850);
    expect(s.bankMovement, 7850);
    final october = TaxPeriodSummary.between(entries: [bank, expense],
      transactions: [payment], first: DateTime(2026, 10),
      last: DateTime(2026, 10, 31));
    expect(october.trackedReceipts, 0);
  });
}
