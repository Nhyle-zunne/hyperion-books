import 'package:flutter_test/flutter_test.dart';
import 'package:hyperion_books/models/paymongo_transaction.dart';
import 'package:hyperion_books/services/paymongo_csv_service.dart';
import 'package:hyperion_books/services/paymongo_import_plan.dart';

const header = 'Transaction ID,Type,Currency,Gross Amount,Fee,VAT,Net Amount,'
  'Status,Transaction Date,Payment Method\n';
const rowA = 'pay_same001,Payment,PHP,100.00,-1.50,-0.16,98.50,'
  'Paid,2026-11-03 14:20,qrph\n';
const rowB = 'pay_same002,Payment,PHP,100.00,-1.50,-0.16,98.50,'
  'Paid,2026-11-03 14:20,qrph\n';
const rowC = 'pay_new003,Payment,PHP,200.00,-3.00,-0.32,197.00,'
  'Paid,2026-11-04 10:15,qrph\n';

void main() {
  test('same file again, renamed file, and reordered file contain zero new IDs', () {
    final first = PayMongoCsvService.parse(header + rowA + rowB).transactions;
    final same = PayMongoCsvService.parse(header + rowA + rowB).transactions;
    final reordered = PayMongoCsvService.parse(header + rowB + rowA).transactions;

    final exact = PayMongoImportPlan.prepare(incoming: same, existing: first);
    final shuffled = PayMongoImportPlan.prepare(incoming: reordered, existing: first);

    expect(exact.newCount, 0);
    expect(exact.alreadyImported, 2);
    expect(exact.conflictingExisting, 0);
    expect(shuffled.newCount, 0);
    expect(shuffled.alreadyImported, 2);
  });

  test('overlapping exports add only truly new transaction IDs', () {
    final previous = PayMongoCsvService.parse(header + rowA + rowB).transactions;
    final overlap = PayMongoCsvService.parse(header + rowB + rowC).transactions;
    final plan = PayMongoImportPlan.prepare(incoming: overlap, existing: previous);

    expect(plan.newCount, 1);
    expect(plan.alreadyImported, 1);
    expect(plan.newTransactions.single.id, 'pay_new003');
  });

  test('two legitimate purchases with same time and amount stay separate', () {
    final original = PayMongoCsvService.parse(header + rowA).transactions;
    final sameAmountDifferentId = PayMongoCsvService.parse(header + rowB).transactions;
    final plan = PayMongoImportPlan.prepare(
      incoming: sameAmountDifferentId, existing: original);

    expect(plan.newCount, 1);
    expect(plan.alreadyImported, 0);
    expect(plan.newTransactions.single.id, 'pay_same002');
  });

  test('same ID but different amount never overwrites existing transaction', () {
    final previous = PayMongoCsvService.parse(header + rowA).transactions;
    final changed = PayMongoCsvService.parse(
      header + rowA.replaceFirst('98.50', '98.40')).transactions;
    final plan = PayMongoImportPlan.prepare(incoming: changed, existing: previous);

    expect(plan.newCount, 0);
    expect(plan.alreadyImported, 1);
    expect(plan.conflictingExisting, 1);
  });

  test('duplicate items passed to the preview planner are safely skipped', () {
    final same = PayMongoCsvService.parse(header + rowA).transactions.single;
    final plan = PayMongoImportPlan.prepare(
      incoming: [same, same], existing: const <PayMongoTransaction>[]);

    expect(plan.newCount, 1);
    expect(plan.alreadyImported, 1);
  });
}
