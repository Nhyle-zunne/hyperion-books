import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/services/backup_service.dart';

void main() {
  test('purchase, asset and payroll records survive version 3 backups', () {
    final records = [
      BusinessOperationRecord(id: 'purchase-01', kind: 'Purchase',
        description: 'Inventory supply', reference: 'PUR-101',
        counterparty: 'Vendor One', date: DateTime(2026, 11, 2),
        amountCentavos: 185000, status: 'Paid'),
      BusinessOperationRecord(id: 'asset-01', kind: 'Asset',
        description: 'Laptop', date: DateTime(2026, 11, 3),
        amountCentavos: 3300000, status: 'Recorded'),
      BusinessOperationRecord(id: 'payroll-01', kind: 'Payroll',
        description: 'Staff payment', date: DateTime(2026, 11, 4),
        amountCentavos: 1500000, status: 'Paid'),
    ];
    final input = BusinessWorkspace(operations: records);
    final saved = BackupService.encode([], workspace: input);
    final restored = BackupService.decodeFull(saved).workspace;
    expect(restored.operations.map((r) => r.kind).toList(),
      ['Purchase','Asset','Payroll']);
    expect(restored.operations.first.amountCentavos, 185000);
    expect(restored.operations.first.reference, 'PUR-101');
  });

  test('older backups without operating records remain supported', () {
    final raw = jsonDecode(BackupService.encode([])) as Map<String, dynamic>;
    final workspace = raw['workspace'] as Map<String, dynamic>;
    workspace.remove('operation_records');
    final restored = BackupService.decodeFull(jsonEncode(raw));
    expect(restored.workspace.operations, isEmpty);
  });

  test('invalid or duplicate register IDs reject the backup', () {
    final item = BusinessOperationRecord(id: 'asset-1', kind: 'Asset',
      description: 'Equipment', date: DateTime(2026, 11, 5),
      amountCentavos: 20000);
    final original = jsonDecode(BackupService.encode([],
      workspace: BusinessWorkspace(operations: [item])))
      as Map<String, dynamic>;
    final rows = (original['workspace'] as Map<String, dynamic>)['operation_records'] as List;
    rows.add(Map<String, dynamic>.from(rows.first as Map));
    expect(() => BackupService.decodeFull(jsonEncode(original)),
      throwsFormatException);
    rows.removeLast();
    (rows.first as Map<String,dynamic>)['amount_centavos'] = -100;
    expect(() => BackupService.decodeFull(jsonEncode(original)),
      throwsFormatException);
  });

  test('manual invoice due dates round-trip, including old invoices', () {
    final invoice = TaxRecord(id:'invoice-1', kind:'Invoice',
      name:'Buyer', reference:'INV-101',
      date:DateTime(2026,11,2), dueDate:DateTime(2026,12,2),
      amountCentavos:150000, status:'Issued');
    final backup = BackupService.encode([], workspace:
      BusinessWorkspace(taxRecords:[invoice]));
    final parsed = BackupService.decodeFull(backup).workspace.taxRecords.single;
    expect(parsed.dueDate,DateTime(2026,12,2));
    final raw = jsonDecode(backup) as Map<String,dynamic>;
    ((raw['workspace'] as Map<String,dynamic>)['tax_records'] as List)
      .first.remove('due_date');
    final older = BackupService.decodeFull(jsonEncode(raw)).workspace.taxRecords.single;
    expect(older.dueDate,isNull);
  });
}
