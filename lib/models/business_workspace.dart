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

class BusinessWorkspace {
  final String businessName, registrationStatus, taxStatus, notes;
  final List<BusinessListItem> masters;
  final List<BusinessReminder> reminders;

  const BusinessWorkspace({
    this.businessName = '',
    this.registrationStatus = 'Not specified',
    this.taxStatus = 'Not specified',
    this.notes = '',
    this.masters = const [],
    this.reminders = const [],
  });

  BusinessWorkspace copyWith({
    String? businessName, String? registrationStatus,
    String? taxStatus, String? notes,
    List<BusinessListItem>? masters,
    List<BusinessReminder>? reminders,
  }) => BusinessWorkspace(
    businessName: businessName ?? this.businessName,
    registrationStatus: registrationStatus ?? this.registrationStatus,
    taxStatus: taxStatus ?? this.taxStatus,
    notes: notes ?? this.notes,
    masters: List.unmodifiable(masters ?? this.masters),
    reminders: List.unmodifiable(reminders ?? this.reminders),
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
    'registration_status': registrationStatus,
    'tax_status': taxStatus,
    'notes': notes,
    'masters': masters.map((e) => e.toJson()).toList(),
    'reminders': reminders.map((e) => e.toJson()).toList(),
  };

  factory BusinessWorkspace.fromJson(Map<String, dynamic> json) {
    final name = json['business_name'] ?? '';
    final reg = json['registration_status'] ?? 'Not specified';
    final tax = json['tax_status'] ?? 'Not specified';
    final notes = json['notes'] ?? '';
    final rawMasters = json['masters'] ?? [];
    final rawReminders = json['reminders'] ?? [];
    if (name is! String || name.length > 180 ||
        reg is! String || !registrationStatuses.contains(reg) ||
        tax is! String || !taxStatuses.contains(tax) ||
        notes is! String || notes.length > 3000 ||
        rawMasters is! List || rawMasters.length > 10000 ||
        rawReminders is! List || rawReminders.length > 10000) {
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
    return BusinessWorkspace(
      businessName: name.trim(), registrationStatus: reg,
      taxStatus: tax, notes: notes,
      masters: List.unmodifiable(masters),
      reminders: List.unmodifiable(reminders),
    );
  }
}
