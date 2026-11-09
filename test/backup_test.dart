import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/book_entry.dart';
import 'package:hyperion_books/models/reports.dart';
import 'package:hyperion_books/services/backup_service.dart';

void main() {
  final originals = <BookEntry>[
    BookEntry(id: 'paymongo-0001', userId: 'local', kind: EntryKind.payout,
      date: DateTime(2026, 11, 9), platform: 'PayMongo', description: 'Weekly',
      category: '', amountCentavos: 454755, grossCentavos: 500000),
    BookEntry(id: 'expense-0001', userId: 'local', kind: EntryKind.expense,
      date: DateTime(2026, 11, 8), platform: '', description: 'Hosting',
      category: 'Software', amountCentavos: 100000),
  ];

  test('backup round trip preserves entries, IDs and balances', () {
    final saved = BackupService.encode(originals);
    final restored = BackupService.decode(saved);
    expect(restored.length, 2);
    expect(restored.first.id, 'paymongo-0001');
    expect(restored.first.grossCentavos, 500000);
    expect(restored.last.description, 'Hosting');
    expect(BooksReport.fromEntries(restored).netCashMovement, 354755);
    expect(BooksReport.fromEntries(restored).journalBalanced, isTrue);
  });

  test('rejects unsupported format and duplicate entry IDs', () {
    expect(() => BackupService.decode('{"format":"unknown","entries":[]}'), throwsFormatException);
    final duplicate = jsonDecode(BackupService.encode([originals.first, originals.first]));
    expect(() => BackupService.decode(jsonEncode(duplicate)), throwsFormatException);
  });

  test('rejects invalid money and dates', () {
    final data = jsonDecode(BackupService.encode([originals.first])) as Map<String, dynamic>;
    final e = (data['entries'] as List).first as Map<String, dynamic>;
    e['amount_centavos'] = -20;
    expect(() => BackupService.decode(jsonEncode(data)), throwsFormatException);
    e['amount_centavos'] = 454755;
    e['date'] = '2026-02-31';
    expect(() => BackupService.decode(jsonEncode(data)), throwsFormatException);
  });
}
