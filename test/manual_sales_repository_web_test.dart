import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/data/local_repository.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';

PayMongoTransaction direct(String id, String ref, {int amount = 4500}) =>
  PayMongoTransaction(
    id: id, type: 'Payment', status: 'Paid',
    source: 'manual', paymentMethod: 'Bank Transfer',
    occurredAt: DateTime(2026, 11, 10, 14),
    grossCentavos: amount, feeCentavos: 0, vatCentavos: 0,
    netCentavos: amount,
    reference: ref, description: 'Hyperion review access',
  );

PayMongoTransaction imported(String id) => PayMongoTransaction(
  id: id, type: 'Payment', status: 'Paid',
  paymentMethod: 'QR Ph', occurredAt: DateTime(2026, 11, 10, 14),
  grossCentavos: 4500, feeCentavos: 0, vatCentavos: 0,
  netCentavos: 4500,
);

void main() {
  test('manual sale is editable, persisted, deduplicated and deletable', () async {
    var repo = await LocalRepository.open();
    try {
      await repo.replaceAll([], []);
      final first = direct('manual_test0001', 'BANK-REF-001');
      await repo.saveManualSale(first);
      await repo.close();
      repo = await LocalRepository.open();
      expect((await repo.listPayMongo()).single.isManual, isTrue);
      expect((await repo.listPayMongo()).single.reference, 'BANK-REF-001');

      final updated = direct('manual_test0001', 'BANK-REF-001', amount: 8000);
      await repo.saveManualSale(updated);
      expect((await repo.listPayMongo()).single.grossCentavos, 8000,
        reason: 'Editing must replace the original sale, not add another.');

      await expectLater(
        repo.saveManualSale(direct('manual_test0002', 'bank-ref-001')),
        throwsA(isA<StateError>()),
      );

      // Importing a CSV with an already recorded bank reference is skipped.
      expect(await repo.importPayMongo([imported('BANK-REF-001')]), 0);
      expect((await repo.listPayMongo()).length, 1);

      expect(await repo.importPayMongo([imported('pay_other001')]), 1);
      await expectLater(repo.removeManualSale('pay_other001'),
        throwsA(isA<StateError>()));
      await repo.removeManualSale(first.id);
      final remaining = await repo.listPayMongo();
      expect(remaining.length, 1);
      expect(remaining.single.id, 'pay_other001');
    } finally {
      await repo.replaceAll([], []);
      await repo.close();
    }
  });
}
