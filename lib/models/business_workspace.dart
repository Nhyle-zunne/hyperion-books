import 'book_entry.dart';

const businessListKinds = ['Customer', 'Vendor', 'Product', 'Expense category'];

class BusinessListItem {
  final String id, kind, name, details;
  final int? priceCentavos;
  const BusinessListItem({
    required this.id, required this.kind,
    required this.name, this.details = '', this.priceCentavos,
  });

  Map<String, Object?> toJson() => {
    'id': id, 'kind': kind, 'name': name,
    'details': details, 'price_centavos': priceCentavos,
  };

  factory BusinessListItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'], kind = json['kind'];
    final name = json['name'], details = json['details'] ?? '';
    final price = json['price_centavos'];
    if (id is! String || id.isEmpty || id.length > 120 ||
        kind is! String || !businessListKinds.contains(kind) ||
        name is! String || name.trim().isEmpty || name.length > 160 ||
        details is! String || details.length > 500 ||
        (price != null && (price is! int || price < 0 ||
            price > 100000000000000))) {
      throw const FormatException('Invalid business master-list item.');
    }
    return BusinessListItem(id: id, kind: kind, name: name.trim(),
      details: details, priceCentavos: price);
  }
}

class BusinessReminder {
  final String id, title, notes;
  final DateTime dueDate;
  final bool completed;

  const BusinessReminder({
    required this.id, required this.title, required this.dueDate,
    this.notes = '', this.completed = false,
  });

  BusinessReminder copyWith({String? title, String? notes,
      DateTime? dueDate, bool? completed}) =>
    BusinessReminder(id: id, title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed);

  Map<String, Object?> toJson() => {
    'id': id, 'title': title, 'notes': notes,
    'due_date': BookEntry.dateKeyOf(dueDate), 'completed': completed,
  };

  factory BusinessReminder.fromJson(Map<String, dynamic> json) {
    final id = json['id'], title = json['title'];
    final notes = json['notes'] ?? '';
    final date = json['due_date'], completed = json['completed'] ?? false;
    final parsed = date is String ? DateTime.tryParse(date) : null;
    if (id is! String || id.isEmpty || id.length > 120 ||
        title is! String || title.trim().isEmpty || title.length > 160 ||
        notes is! String || notes.length > 1000 ||
        date is! String || parsed == null ||
        BookEntry.dateKeyOf(parsed) != date ||
        completed is! bool) {
      throw const FormatException('Invalid business reminder.');
    }
    return BusinessReminder(id: id, title: title.trim(), notes: notes,
      dueDate: parsed, completed: completed);
  }
}

const registrationStatuses = [
  'Not specified', 'Planning', 'Registered', 'Inactive / closed',
];
const taxStatuses = [
  'Not specified', '8% income tax (if elected)',
  'Graduated income tax', 'VAT registered',
  'Non-VAT / percentage tax', 'Consult accountant',
];


const taxRecordKinds = ['Filing', '2307', 'Invoice'];
const taxRecordStatuses = ['Draft', 'Filed', 'Issued', 'Received', 'Paid', 'Cancelled'];
const taxRecordDirections = ['', 'Incoming', 'Outgoing'];

/// A user-maintained registry item. It is NOT a BIR-submitted or verified return,
/// tax certificate or legally issued electronic invoice.
class TaxRecord {
  final String id, kind, name, reference, period, status, direction, notes;
  final DateTime date;
  final int amountCentavos;
  const TaxRecord({
    required this.id, required this.kind, required this.name,
    required this.reference, required this.date,
    this.period = '', this.status = 'Draft', this.direction = '',
    this.notes = '', this.amountCentavos = 0,
  });
  Map<String, Object?> toJson() => {
    'id': id, 'kind': kind, 'name': name, 'reference': reference,
    'period': period, 'date': BookEntry.dateKeyOf(date),
    'status': status, 'direction': direction,
    'notes': notes, 'amount_centavos': amountCentavos,
  };
  factory TaxRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'], kind = json['kind'];
    final name = json['name'], reference = json['reference'];
    final period = json['period'] ?? '';
    final date = json['date'], status = json['status'] ?? 'Draft';
    final direction = json['direction'] ?? '', notes = json['notes'] ?? '';
    final amount = json['amount_centavos'] ?? 0;
    final parsed = date is String ? DateTime.tryParse(date) : null;
    if (id is! String || id.isEmpty || id.length > 120 ||
        kind is! String || !taxRecordKinds.contains(kind) ||
        name is! String || name.trim().isEmpty || name.length > 180 ||
        reference is! String || reference.length > 160 ||
        period is! String || period.length > 40 ||
        parsed == null || date != BookEntry.dateKeyOf(parsed) ||
        status is! String || !taxRecordStatuses.contains(status) ||
        direction is! String || !taxRecordDirections.contains(direction) ||
        notes is! String || notes.length > 1500 ||
        amount is! int || amount < 0 || amount > 100000000000000) {
      throw const FormatException('Invalid local tax tracking record.');
    }
    return TaxRecord(id: id, kind: kind, name: name.trim(),
      reference: reference.trim(), period: period.trim(), date: parsed,
      status: status, direction: direction, notes: notes,
      amountCentavos: amount);
  }
}

class BusinessWorkspace {
  final String businessName, businessTin, businessAddress,
      registrationStatus, taxStatus, notes;
  final List<BusinessListItem> masters;
  final List<BusinessReminder> reminders;
  final List<TaxRecord> taxRecords;
  final List<String> verifiedReferences, voidedReferences;

  const BusinessWorkspace({
    this.businessName = '',
    this.businessTin = '',
    this.businessAddress = '',
    this.registrationStatus = 'Not specified',
    this.taxStatus = 'Not specified',
    this.notes = '',
    this.masters = const [],
    this.reminders = const [],
    this.taxRecords = const [],
    this.verifiedReferences = const [],
    this.voidedReferences = const [],
  });

  BusinessWorkspace copyWith({
    String? businessName, String? businessTin, String? businessAddress,
    String? registrationStatus,
    String? taxStatus, String? notes,
    List<BusinessListItem>? masters,
    List<BusinessReminder>? reminders,
    List<TaxRecord>? taxRecords,
    List<String>? verifiedReferences,
    List<String>? voidedReferences,
  }) => BusinessWorkspace(
    businessName: businessName ?? this.businessName,
    businessTin: businessTin ?? this.businessTin,
    businessAddress: businessAddress ?? this.businessAddress,
    registrationStatus: registrationStatus ?? this.registrationStatus,
    taxStatus: taxStatus ?? this.taxStatus,
    notes: notes ?? this.notes,
    masters: List.unmodifiable(masters ?? this.masters),
    reminders: List.unmodifiable(reminders ?? this.reminders),
    taxRecords: List.unmodifiable(taxRecords ?? this.taxRecords),
    verifiedReferences: List.unmodifiable(verifiedReferences ?? this.verifiedReferences),
    voidedReferences: List.unmodifiable(voidedReferences ?? this.voidedReferences),
  );

  List<String> get expenseCategories {
    final names = <String>{
      'General', 'Software', 'Advertising', 'Equipment', 'Bank fees',
      'Professional services', 'Other',
      ...masters.where((e) => e.kind == 'Expense category').map((e) => e.name),
    };
    return names.toList()..sort();
  }

  Map<String, Object?> toJson() => {
    'business_name': businessName,
    'business_tin': businessTin,
    'business_address': businessAddress,
    'registration_status': registrationStatus,
    'tax_status': taxStatus,
    'notes': notes,
    'masters': masters.map((e) => e.toJson()).toList(),
    'reminders': reminders.map((e) => e.toJson()).toList(),
    'tax_records': taxRecords.map((e) => e.toJson()).toList(),
    'verified_references': verifiedReferences,
    'voided_references': voidedReferences,
  };

  factory BusinessWorkspace.fromJson(Map<String, dynamic> json) {
    final name = json['business_name'] ?? '';
    final tin = json['business_tin'] ?? '';
    final address = json['business_address'] ?? '';
    final reg = json['registration_status'] ?? 'Not specified';
    final tax = json['tax_status'] ?? 'Not specified';
    final notes = json['notes'] ?? '';
    final rawMasters = json['masters'] ?? [];
    final rawReminders = json['reminders'] ?? [];
    final rawTaxRecords = json['tax_records'] ?? [];
    final rawVerified = json['verified_references'] ?? [];
    final rawVoided = json['voided_references'] ?? [];
    if (name is! String || name.length > 180 ||
        tin is! String || tin.length > 40 ||
        address is! String || address.length > 400 ||
        reg is! String || !registrationStatuses.contains(reg) ||
        tax is! String || !taxStatuses.contains(tax) ||
        notes is! String || notes.length > 3000 ||
        rawMasters is! List || rawMasters.length > 10000 ||
        rawReminders is! List || rawReminders.length > 10000 ||
        rawTaxRecords is! List || rawTaxRecords.length > 10000 ||
        rawVerified is! List || rawVerified.length > 100000 ||
        rawVoided is! List || rawVoided.length > 100000) {
      throw const FormatException('Invalid business settings in backup.');
    }
    final masters = <BusinessListItem>[];
    final reminders = <BusinessReminder>[];
    final ids = <String>{};
    for (final raw in rawMasters) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid master-list item.');
      }
      final item = BusinessListItem.fromJson(raw);
      if (!ids.add(item.id)) {
        throw const FormatException('Duplicate master-list ID.');
      }
      masters.add(item);
    }
    ids.clear();
    for (final raw in rawReminders) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid reminder.');
      }
      final item = BusinessReminder.fromJson(raw);
      if (!ids.add(item.id)) {
        throw const FormatException('Duplicate reminder ID.');
      }
      reminders.add(item);
    }

    final taxRecords = <TaxRecord>[];
    ids.clear();
    for (final raw in rawTaxRecords) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid tax tracking record.');
      }
      final item = TaxRecord.fromJson(raw);
      if (!ids.add(item.id)) {
        throw const FormatException('Duplicate tax tracking reference ID.');
      }
      taxRecords.add(item);
    }
    List<String> validReferences(List<dynamic> raw) {
      final result = <String>[];
      final unique = <String>{};
      for (final value in raw) {
        if (value is! String || value.isEmpty || value.length > 160 ||
            !unique.add(value)) {
          throw const FormatException('Invalid or duplicate book audit reference.');
        }
        result.add(value);
      }
      return List.unmodifiable(result);
    }
    return BusinessWorkspace(
      businessName: name.trim(), businessTin: tin.trim(),
      businessAddress: address.trim(), registrationStatus: reg,
      taxStatus: tax, notes: notes,
      masters: List.unmodifiable(masters),
      reminders: List.unmodifiable(reminders),
      taxRecords: List.unmodifiable(taxRecords),
      verifiedReferences: validReferences(rawVerified),
      voidedReferences: validReferences(rawVoided),
    );
  }
}
