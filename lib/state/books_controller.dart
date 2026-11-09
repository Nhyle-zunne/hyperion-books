import 'package:flutter/foundation.dart';
import '../data/local_repository.dart';
import '../models/book_entry.dart';
import '../models/reports.dart';

/// Device-local books. There is no server, OAuth, or automatic cross-device sync.
class BooksController extends ChangeNotifier {
  LocalRepository? _repository;
  bool _loading = true;
  String _status = 'Opening your local books…';
  List<BookEntry> _entries = [];

  String get status => _status;
  bool get loading => _loading;
  bool get ready => _repository != null;
  String get userId => 'local';
  List<BookEntry> get entries => List.unmodifiable(_entries);
  BooksReport get report => BooksReport.fromEntries(_entries);

  Future<void> start() async {
    try {
      _repository = await LocalRepository.open();
      await _reload();
      _status = 'Saved locally on this device · Back up regularly.';
    } catch (error) {
      _status = 'Could not open browser storage: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    final repo = _repository;
    if (repo == null) return;
    _entries = (await repo.list()).where((entry) => !entry.deleted).toList();
    _entries.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    notifyListeners();
  }

  Future<void> save(BookEntry entry) async {
    final repo = _repository;
    if (repo == null) throw StateError('Local storage is not available');
    if (entry.amountCentavos <= 0 ||
        (entry.grossCentavos != null && entry.grossCentavos! < entry.amountCentavos)) {
      throw ArgumentError('Enter a positive amount; gross cannot be less than net.');
    }
    await repo.upsert(entry);
    await _reload();
    _status = 'Saved locally. Export a JSON backup to protect your records.';
    notifyListeners();
  }

  Future<void> remove(BookEntry entry) async {
    final repo = _repository;
    if (repo == null) throw StateError('Local storage is not available');
    await repo.remove(entry.id);
    await _reload();
    _status = 'Entry deleted locally. Export a new backup.';
    notifyListeners();
  }

  /// Explicit overwrite only. The UI must preview totals and confirm first.
  Future<void> restore(List<BookEntry> entries) async {
    final repo = _repository;
    if (repo == null) throw StateError('Local storage is not available');
    await repo.replaceAll(entries);
    await _reload();
    _status = 'Restored ${entries.length} entries from backup on this device.';
    notifyListeners();
  }

  @override
  void dispose() {
    final repository = _repository;
    if (repository != null) repository.close();
    super.dispose();
  }
}
