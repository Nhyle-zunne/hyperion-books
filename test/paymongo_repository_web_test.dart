import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/data/local_repository.dart';
import 'package:hyperion_books/services/paymongo_csv_service.dart';

const csvHeader = 'Transaction ID,Type,Currency,Gross Amount,Fee,VAT,'
  'Net Amount,Status,Transaction Date,Payment Method\n';
const row1 = 'pay_storage001,Payment,PHP,100,-1.5,-0.16,98.5,'
  'Paid,2026-11-03 14:20,qrph\n';
const row2 = 'pay_storage002,Payment,PHP,25,-0.5,-0.05,24.5,'
  'Paid,2026-11-04 10:15,qrph\n';
const row3 = 'pay_storage003,Payment,PHP,30,-0.5,-0.05,29.5,'
  'Paid,2026-11-05 09:12,qrph\n';
const row4 = 'pay_storage004,Payment,PHP,40,-0.5,-0.05,39.5,'
  'Paid,2026-11-06 12:00,qrph\n';

void main() {
  test('IndexedDB import remains idempotent after repeat, reordered, '
      'overlapping and concurrent CSV imports', () async {
    var repo = await LocalRepository.open();
    try {
      // Tests use GitHub Actions' isolated browser, never a user's database.
      await repo.replaceAll([], []);

      final first = PayMongoCsvService.parse(csvHeader + row1 + row2).transactions;
      expect(await repo.importPayMongo(first), 2);
      expect(await repo.importPayMongo(first), 0,
        reason: 'Importing the exact same CSV twice adds nothing');

      final reordered = PayMongoCsvService.parse(csvHeader + row2 + row1).transactions;
      expect(await repo.importPayMongo(reordered), 0,
        reason: 'Renamed/reordered copies are deduplicated by transaction ID');

      final overlap = PayMongoCsvService.parse(csvHeader + row3 + row2).transactions;
      expect(await repo.importPayMongo(overlap), 1);
      expect((await repo.listPayMongo()).map((e) => e.id).toSet(), {
        'pay_storage001', 'pay_storage002', 'pay_storage003',
      });

      final changed = PayMongoCsvService.parse(csvHeader +
        row1.replaceFirst('98.5', '97.5')).transactions;
      expect(await repo.importPayMongo(changed), 0);
      final original = (await repo.listPayMongo()).singleWhere(
        (e) => e.id == 'pay_storage001');
      expect(original.netCentavos, 9850,
        reason: 'A changed export must never overwrite an existing ID');

      final finalBatch = PayMongoCsvService.parse(csvHeader + row4).transactions;
      final parallel = await Future.wait([
        repo.importPayMongo(finalBatch),
        repo.importPayMongo(finalBatch),
      ]);
      expect(parallel.reduce((a, b) => a + b), 1);
      expect((await repo.listPayMongo()).length, 4);

      await repo.close();
      repo = await LocalRepository.open();
      expect((await repo.listPayMongo()).length, 4,
        reason: 'Deduplication survives closing/reopening the app');
      expect(await repo.importPayMongo(first), 0);
    } finally {
      await repo.replaceAll([], []);
      await repo.close();
    }
  });
}
