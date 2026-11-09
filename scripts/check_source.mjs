import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const root = new URL('../', import.meta.url).pathname;
const source = (file) => readFileSync(join(root, file), 'utf8');
for (const file of [
  'lib/main.dart','lib/models/book_entry.dart','lib/models/reports.dart',
  'lib/data/local_repository.dart','lib/state/books_controller.dart',
  'lib/services/backup_service.dart','lib/services/export_service.dart',
  'lib/ui/entry_dialog.dart','lib/ui/home.dart','scripts/make_sw.mjs',
  'test/book_entry_test.dart','test/backup_test.dart','web/index.html','web/manifest.json',
  '.github/workflows/pages.yml',
]) assert(existsSync(join(root, file)), `Missing ${file}`);
const pubspec = source('pubspec.yaml');
assert(!pubspec.includes('supabase_flutter'), 'Cloud dependency remains');
assert(pubspec.includes('file_selector'), 'Import picker missing');
const local = source('lib/data/local_repository.dart');
assert(local.includes('databaseFactoryWeb') && local.includes('replaceAll') && local.includes('db.transaction'), 'Atomic IndexedDB restore missing');
const controller = source('lib/state/books_controller.dart');
assert(!controller.includes('SupabaseClient') && controller.includes('LocalRepository.open()'), 'Controller is not local-first');
const form = source('lib/ui/entry_dialog.dart');
assert(form.includes('showDatePicker'), 'Calendar picker missing');
const backup = source('lib/services/backup_service.dart');
assert(backup.includes('schema_version') && backup.includes('decode') && backup.includes('selectAndRead'), 'Restorable backup missing');
const excel = source('lib/services/export_service.dart');
for (const tab of ['PAYOUTS','EXPENSES','CASH RECEIPTS','CASH DISBURSEMENTS','GENERAL JOURNAL','GENERAL LEDGER','MONTHLY SUMMARY']) {
  assert(excel.includes(`'${tab}'`), `Excel sheet missing: ${tab}`);
}
const report = source('lib/models/reports.dart');
assert(report.includes('journalBalanced'), 'Double-entry accounting missing');
assert(source('web/index.html').includes('serviceWorker.register'), 'Offline app worker missing');
assert(source('web/manifest.json').includes('"start_url": "."'), 'GitHub Pages subpath support missing');
console.log('PASS: local-first storage, picker, journal, Excel, JSON backup/restore, GitHub Pages subpath, offline shell.');
