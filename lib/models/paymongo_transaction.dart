/// One transaction from PayMongo's transaction CSV, not a bank payout.
///
/// Customer names, email, phone and billing fields are deliberately not stored.
class PayMongoTransaction {
  final String id;
  final String type;
  final String status;
  final String paymentMethod;
  /// Exact local wall-clock date/time shown in the PayMongo CSV. Its timezone
  /// is unspecified in the source, so do not convert it to another timezone.
  final DateTime occurredAt;
  final int grossCentavos;
  /// Signed amounts exactly as exported. PayMongo's Fee includes the VAT
  /// component, so VAT must NOT be subtracted a second time.
  final int feeCentavos;
  final int vatCentavos;
  final int netCentavos;

  const PayMongoTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.occurredAt,
    required this.grossCentavos,
    required this.feeCentavos,
    required this.vatCentavos,
    required this.netCentavos,
  });

  bool get isPayment => type == 'Payment';

  String get month => '${occurredAt.year.toString().padLeft(4, '0')}-'
      '${occurredAt.month.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'status': status,
    'payment_method': paymentMethod,
    'occurred_at': occurredAt.toIso8601String(),
    'gross_centavos': grossCentavos,
    'fee_centavos': feeCentavos,
    'vat_centavos': vatCentavos,
    'net_centavos': netCentavos,
  };

  factory PayMongoTransaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final status = json['status'];
    final method = json['payment_method'];
    final datetime = json['occurred_at'];
    final gross = json['gross_centavos'];
    final fee = json['fee_centavos'];
    final vat = json['vat_centavos'];
    final net = json['net_centavos'];
    final d = datetime is String ? DateTime.tryParse(datetime) : null;
    final money = [gross, fee, vat, net];
    if (id is! String || id.length < 6 || id.length > 160 ||
        !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id) ||
        (type != 'Payment' && type != 'Adjustment' && type != 'Refund') ||
        status is! String || status.length > 60 ||
        method is! String || method.length > 80 ||
        d == null || d.year < 2000 || d.year > 2100 || d.isUtc ||
        money.any((x) => x is! int || x.abs() > 100000000000000)) {
      throw const FormatException('Invalid PayMongo transaction in backup');
    }
    return PayMongoTransaction(
      id: id, type: type as String, status: status,
      paymentMethod: method, occurredAt: d,
      grossCentavos: gross, feeCentavos: fee,
      vatCentavos: vat, netCentavos: net,
    );
  }
}

class PayMongoTotals {
  final int payments;
  final int adjustments;
  final int grossPaymentsCentavos;
  final int paymentFeesCentavos;
  final int paymentVatCentavos;
  final int netPaymentsCentavos;
  final int adjustmentsNetCentavos;

  const PayMongoTotals({
    required this.payments,
    required this.adjustments,
    required this.grossPaymentsCentavos,
    required this.paymentFeesCentavos,
    required this.paymentVatCentavos,
    required this.netPaymentsCentavos,
    required this.adjustmentsNetCentavos,
  });

  int get activityNetCentavos => netPaymentsCentavos + adjustmentsNetCentavos;

  factory PayMongoTotals.fromTransactions(Iterable<PayMongoTransaction> records) {
    var payments = 0, adjustments = 0;
    var gross = 0, fees = 0, vat = 0, net = 0, adjustmentNet = 0;
    for (final row in records) {
      if (row.isPayment) {
        payments++;
        gross += row.grossCentavos;
        fees += -row.feeCentavos;
        vat += -row.vatCentavos;
        net += row.netCentavos;
      } else {
        adjustments++;
        adjustmentNet += row.netCentavos;
      }
    }
    return PayMongoTotals(payments: payments, adjustments: adjustments,
      grossPaymentsCentavos: gross, paymentFeesCentavos: fees,
      paymentVatCentavos: vat, netPaymentsCentavos: net,
      adjustmentsNetCentavos: adjustmentNet);
  }
}
