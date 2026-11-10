import '../models/paymongo_transaction.dart';

/// Previews an import without modifying local records.
/// Identity is PayMongo Transaction ID, not the CSV filename or row order.
/// Matching amounts/dates alone are NOT a safe deduplication key: legitimate
/// customer payments can share all of those fields.
class PayMongoImportPlan {
  final List<PayMongoTransaction> newTransactions;
  final int alreadyImported;
  final int conflictingExisting;
  final int customerDetailsToEnrich;

  const PayMongoImportPlan({
    required this.newTransactions,
    required this.alreadyImported,
    required this.conflictingExisting,
    this.customerDetailsToEnrich = 0,
  });

  int get newCount => newTransactions.length;

  /// No records can be duplicated by re-importing the same Transaction IDs.
  /// Existing IDs are never overwritten, even when later exports disagree.
  static PayMongoImportPlan prepare({
    required Iterable<PayMongoTransaction> incoming,
    required Iterable<PayMongoTransaction> existing,
  }) {
    final byId = <String, PayMongoTransaction>{
      for (final item in existing) item.id: item,
    };
    final seenInFile = <String>{};
    final add = <PayMongoTransaction>[];
    var skipped = 0, conflicts = 0, enrichable = 0;
    for (final item in incoming) {
      // Parsing already rejects repeated IDs within one CSV; retain this
      // safeguard if the plan is ever used with a different input source.
      if (!seenInFile.add(item.id)) {
        skipped++;
        continue;
      }
      final previous = byId[item.id];
      if (previous == null) {
        add.add(item);
      } else {
        skipped++;
        if (!_sameTransaction(previous, item)) {
          conflicts++;
        } else if (previous.canEnrichFrom(item)) {
          enrichable++;
        }
      }
    }
    return PayMongoImportPlan(
      newTransactions: List.unmodifiable(add),
      alreadyImported: skipped,
      conflictingExisting: conflicts,
      customerDetailsToEnrich: enrichable,
    );
  }

  static bool _sameTransaction(
    PayMongoTransaction a, PayMongoTransaction b,
  ) => a.type == b.type &&
       a.status == b.status &&
       a.paymentMethod == b.paymentMethod &&
       a.occurredAt.isAtSameMomentAs(b.occurredAt) &&
       a.grossCentavos == b.grossCentavos &&
       a.feeCentavos == b.feeCentavos &&
       a.vatCentavos == b.vatCentavos &&
       a.netCentavos == b.netCentavos;
}
