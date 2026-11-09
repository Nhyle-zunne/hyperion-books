import 'package:uuid/uuid.dart';

enum EntryKind { payout, expense }

class BookEntry {
  final String id;
  final String userId;
  final EntryKind kind;
  final DateTime date;
  final String platform;
  final String description;
  final String category;
  final int amountCentavos;
  final int? grossCentavos;
  final int version;
  final int editSequence;
  final bool dirty;
  final bool deleted;
  final bool conflict;

  const BookEntry({
    required this.id,
    required this.userId,
    required this.kind,
    required this.date,
    required this.platform,
    required this.description,
    required this.category,
    required this.amountCentavos,
    this.grossCentavos,
    this.version = 0,
    this.editSequence = 1,
    this.dirty = true,
    this.deleted = false,
    this.conflict = false,
  });

  static BookEntry create({
    required String userId,
    required EntryKind kind,
    required DateTime date,
    required String platform,
    required String description,
    required String category,
    required int amountCentavos,
    int? grossCentavos,
  }) => BookEntry(
    id: const Uuid().v4(),
    userId: userId,
    kind: kind,
    date: DateTime(date.year, date.month, date.day),
    platform: platform,
    description: description.trim(),
    category: category,
    amountCentavos: amountCentavos,
    grossCentavos: grossCentavos,
  );

  int get deductionCentavos => grossCentavos == null ? 0 : grossCentavos! - amountCentavos;
  int get receiptsCentavos => grossCentavos ?? amountCentavos;
  String get dateKey => dateKeyOf(date);

  static String dateKeyOf(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  BookEntry copyWith({
    String? userId,
    DateTime? date,
    String? platform,
    String? description,
    String? category,
    int? amountCentavos,
    int? grossCentavos,
    bool clearGross = false,
    int? version,
    int? editSequence,
    bool? dirty,
    bool? deleted,
    bool? conflict,
  }) => BookEntry(
    id: id,
    userId: userId ?? this.userId,
    kind: kind,
    date: date ?? this.date,
    platform: platform ?? this.platform,
    description: description ?? this.description,
    category: category ?? this.category,
    amountCentavos: amountCentavos ?? this.amountCentavos,
    grossCentavos: clearGross ? null : grossCentavos ?? this.grossCentavos,
    version: version ?? this.version,
    editSequence: editSequence ?? this.editSequence,
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    conflict: conflict ?? this.conflict,
  );

  BookEntry markEdited({
    required DateTime date,
    required String platform,
    required String description,
    required String category,
    required int amountCentavos,
    int? grossCentavos,
  }) => BookEntry(
    id: id, userId: userId, kind: kind,
    date: DateTime(date.year, date.month, date.day),
    platform: platform, description: description.trim(), category: category,
    amountCentavos: amountCentavos, grossCentavos: grossCentavos,
    version: version, editSequence: editSequence + 1,
    dirty: true, deleted: false,
  );

  Map<String, Object?> toLocalJson() => {
    'id': id, 'user_id': userId, 'kind': kind.name,
    'date': dateKey, 'platform': platform,
    'description': description, 'category': category,
    'amount_centavos': amountCentavos, 'gross_centavos': grossCentavos,
    'version': version, 'edit_sequence': editSequence,
    'dirty': dirty, 'deleted': deleted, 'conflict': conflict,
  };

  factory BookEntry.fromLocalJson(Map<String, Object?> json) => BookEntry(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    kind: json['kind'] == 'payout' ? EntryKind.payout : EntryKind.expense,
    date: DateTime.parse(json['date'] as String),
    platform: json['platform'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'Other',
    amountCentavos: (json['amount_centavos'] as num).toInt(),
    grossCentavos: (json['gross_centavos'] as num?)?.toInt(),
    version: (json['version'] as num?)?.toInt() ?? 0,
    editSequence: (json['edit_sequence'] as num?)?.toInt() ?? 1,
    dirty: json['dirty'] == true,
    deleted: json['deleted'] == true,
    conflict: json['conflict'] == true,
  );

  Map<String, Object?> toBackupJson() => {
    'id': id, 'kind': kind.name, 'date': dateKey, 'platform': platform,
    'description': description, 'category': category,
    'amount_centavos': amountCentavos, 'gross_centavos': grossCentavos,
  };

  factory BookEntry.fromBackupJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    final dateString = json['date'];
    final platform = json['platform'];
    final description = json['description'];
    final category = json['category'];
    final amount = json['amount_centavos'];
    final gross = json['gross_centavos'];
    if (id is! String || id.length < 8 || id.length > 120 ||
        (kind != 'payout' && kind != 'expense') || dateString is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString) ||
        platform is! String || platform.length > 150 ||
        description is! String || description.length > 1000 ||
        category is! String || category.length > 150 ||
        amount is! int || amount <= 0 || amount > 100000000000000 ||
        (gross != null && (gross is! int || gross < amount || gross > 100000000000000))) {
      throw const FormatException('Invalid payout or expense in backup');
    }
    final date = DateTime.tryParse(dateString);
    if (date == null || dateKeyOf(date) != dateString) {
      throw const FormatException('Invalid transaction date in backup');
    }
    if (kind == 'payout' && platform != 'PayMongo' && platform != 'Google Play') {
      throw const FormatException('Unknown payout source in backup');
    }
    return BookEntry(
      id: id, userId: 'local',
      kind: kind == 'payout' ? EntryKind.payout : EntryKind.expense,
      date: date, platform: platform, description: description, category: category,
      amountCentavos: amount, grossCentavos: gross,
      dirty: false, deleted: false, conflict: false,
    );
  }

}

/// Convert decimal peso text exactly to integer centavos (no binary floating-point).
int? parsePesos(String input) {
  final normalized = input.trim().replaceAll(',', '').replaceAll('₱', '').trim();
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.parse(parts.first);
  final cents = parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0;
  return whole * 100 + cents;
}

String pesoInput(int? amount) {
  if (amount == null) return '';
  return '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
}
