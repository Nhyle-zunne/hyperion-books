/// A sales transaction from an imported spreadsheet or a manually recorded sale.
/// Manual transactions represent money paid directly to a bank, wallet or cash.
/// Optional manual details remain on this device and in unencrypted backups.
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
  final String source;
  final String reference;
  final String description;
  final String customer;
  final String customerEmail;
  final String customerPhone;
  final String customerAddress;
  final String customerTin;
  final String depositAccount;
  final String notes;

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
    this.source = 'import',
    this.reference = '',
    this.description = '',
    this.customer = '',
    this.customerEmail = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.customerTin = '',
    this.depositAccount = '',
    this.notes = '',
  });

  bool get isManual => source == 'manual';

  bool get isPayment => type == 'Payment';

  /// Existing IDs may be enriched only when their accounting values match.
  /// Customer fields are filled when blank; no booked amount is ever changed.
  bool sameAccountingIdentity(PayMongoTransaction other) =>
      id == other.id && type == other.type && status == other.status &&
      paymentMethod == other.paymentMethod &&
      occurredAt.isAtSameMomentAs(other.occurredAt) &&
      grossCentavos == other.grossCentavos &&
      feeCentavos == other.feeCentavos &&
      vatCentavos == other.vatCentavos &&
      netCentavos == other.netCentavos;

  PayMongoTransaction withMissingCustomerDetails(PayMongoTransaction other) =>
      PayMongoTransaction(
        id: id, type: type, status: status, paymentMethod: paymentMethod,
        occurredAt: occurredAt, grossCentavos: grossCentavos,
        feeCentavos: feeCentavos, vatCentavos: vatCentavos,
        netCentavos: netCentavos, source: source,
        reference: reference, description: description, customer:
            customer.isEmpty ? other.customer : customer,
        customerEmail: customerEmail.isEmpty
            ? other.customerEmail : customerEmail,
        customerPhone: customerPhone.isEmpty
            ? other.customerPhone : customerPhone,
        customerAddress: customerAddress.isEmpty
            ? other.customerAddress : customerAddress,
        customerTin: customerTin.isEmpty
            ? other.customerTin : customerTin,
        depositAccount: depositAccount, notes: notes,
      );

  bool canEnrichFrom(PayMongoTransaction other) {
    if (isManual || !sameAccountingIdentity(other)) return false;
    final merged = withMissingCustomerDetails(other);
    return merged.customer != customer ||
        merged.customerEmail != customerEmail ||
        merged.customerPhone != customerPhone ||
        merged.customerAddress != customerAddress ||
        merged.customerTin != customerTin;
  }

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
    'source': source,
    'reference': reference,
    'description': description,
    'customer': customer,
    'customer_email': customerEmail,
    'customer_phone': customerPhone,
    'customer_address': customerAddress,
    'customer_tin': customerTin,
    'deposit_account': depositAccount,
    'notes': notes,
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
    final source = json['source'] ?? 'import';
    final reference = json['reference'] ?? '';
    final description = json['description'] ?? '';
    final customer = json['customer'] ?? '';
    final email = json['customer_email'] ?? '';
    final phone = json['customer_phone'] ?? '';
    final address = json['customer_address'] ?? '';
    final tin = json['customer_tin'] ?? '';
    final account = json['deposit_account'] ?? '';
    final notes = json['notes'] ?? '';
    final d = datetime is String ? DateTime.tryParse(datetime) : null;
    final money = [gross, fee, vat, net];
    if (id is! String || id.length < 6 || id.length > 160 ||
        !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id) ||
        (type != 'Payment' && type != 'Adjustment' && type != 'Refund') ||
        status is! String || status.length > 60 ||
        method is! String || method.length > 80 ||
        d == null || d.year < 2000 || d.year > 2100 || d.isUtc ||
        money.any((x) => x is! int || x.abs() > 100000000000000) ||
        (source != 'import' && source != 'manual') ||
        reference is! String || reference.length > 160 ||
        description is! String || description.length > 180 ||
        customer is! String || customer.length > 160 ||
        email is! String || email.length > 254 ||
        phone is! String || phone.length > 60 ||
        address is! String || address.length > 400 ||
        tin is! String || tin.length > 40 ||
        account is! String || account.length > 160 ||
        notes is! String || notes.length > 1000 ||
        (source == 'manual' && (!id.startsWith('manual_') ||
          type != 'Payment' || gross <= 0 || fee > 0 ||
          net != gross + fee || vat != 0 || description.trim().isEmpty))) {
      throw const FormatException('Invalid PayMongo transaction in backup');
    }
    return PayMongoTransaction(
      id: id, type: type as String, status: status,
      paymentMethod: method, occurredAt: d,
      grossCentavos: gross, feeCentavos: fee,
      vatCentavos: vat, netCentavos: net,
      source: source, reference: reference, description: description,
      customer: customer, customerEmail: email, customerPhone: phone,
      customerAddress: address, customerTin: tin,
      depositAccount: account, notes: notes,
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
