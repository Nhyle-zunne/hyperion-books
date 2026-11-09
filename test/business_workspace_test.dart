import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/business_workspace.dart';
import 'package:hyperion_books/services/backup_service.dart';

void main() {
  final workspace = BusinessWorkspace(
    businessName: 'Example Shop',
    registrationStatus: 'Registered',
    taxStatus: '8% income tax (if elected)',
    notes: 'Personal example, not a verified tax registration',
    masters: const [
      BusinessListItem(
        id: 'vendor-001', kind: 'Vendor',
        name: 'Hosting Vendor', details: 'Recurring software service'),
      BusinessListItem(
        id: 'category-002', kind: 'Expense category',
        name: 'Subscriptions'),
    ],
    reminders: [
      BusinessReminder(
        id: 'task-001', title: 'Review bookkeeping with accountant',
        dueDate: DateTime(2026, 12, 5),
        completed: false, notes: 'Check official dates first'),
    ],
  );

  test('workspace v3 backup round trip retains profile, lists, reminders', () {
    final backup = BackupService.encode([], workspace: workspace);
    final restored = BackupService.decodeFull(backup);
    expect(restored.workspace.businessName, 'Example Shop');
    expect(restored.workspace.registrationStatus, 'Registered');
    expect(restored.workspace.masters.length, 2);
    expect(restored.workspace.reminders.single.dueDate, DateTime(2026, 12, 5));
    expect(restored.workspace.expenseCategories, contains('Subscriptions'));
    expect(restored.entries, isEmpty);
    expect(restored.paymongo, isEmpty);
  });

  test('old v1 and v2 backups still decode with empty workspace', () {
    for (final version in [1, 2]) {
      final raw = jsonDecode(BackupService.encode([])) as Map<String, dynamic>;
      raw['schema_version'] = version;
      raw.remove('workspace');
      if (version == 1) raw.remove('paymongo');
      final parsed = BackupService.decodeFull(jsonEncode(raw));
      expect(parsed.workspace.businessName, isEmpty);
      expect(parsed.workspace.masters, isEmpty);
      expect(parsed.workspace.reminders, isEmpty);
    }
  });

  test('rejects malformed or duplicate business records in backups', () {
    final raw = jsonDecode(BackupService.encode([], workspace: workspace))
        as Map<String, dynamic>;
    final settings = raw['workspace'] as Map<String, dynamic>;
    final masters = settings['masters'] as List;
    masters.add(Map<String, dynamic>.from(masters.first as Map));
    expect(() => BackupService.decodeFull(jsonEncode(raw)),
      throwsFormatException);
    masters.removeLast();
    settings['tax_status'] = 'Fake automatic BIR approved';
    expect(() => BackupService.decodeFull(jsonEncode(raw)),
      throwsFormatException);
  });

  test('manually created reminder supports marking complete', () {
    final done = workspace.reminders.single.copyWith(completed: true);
    expect(done.completed, isTrue);
    expect(done.id, workspace.reminders.single.id);
    expect(done.dueDate, DateTime(2026, 12, 5));
  });
}
