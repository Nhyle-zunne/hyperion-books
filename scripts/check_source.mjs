import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const root = new URL('../', import.meta.url).pathname;
const source = (file) => readFileSync(join(root, file), 'utf8');
for (const file of [
  'lib/main.dart','lib/models/book_entry.dart','lib/models/reports.dart',
  'lib/models/business_workspace.dart','lib/models/business_analytics.dart',
  'lib/ui/business_insights_panel.dart','lib/ui/business_tools.dart',
  'lib/ui/hyperion_sidebar.dart','lib/ui/operation_records_page.dart',
  'lib/ui/business_reports_page.dart','lib/ui/accounting_books_page.dart',
  'lib/ui/record_search.dart','lib/services/expense_csv_service.dart',
  'test/business_workspace_test.dart','test/business_analytics_test.dart','test/expense_csv_test.dart',
  'lib/data/local_repository.dart','lib/state/books_controller.dart',
  'lib/services/backup_service.dart','lib/services/export_service.dart',
  'lib/ui/entry_dialog.dart','lib/ui/home.dart','lib/ui/hyperion_loading.dart','scripts/make_sw.mjs',
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
for (const tab of ['PAYOUTS','EXPENSES','CASH RECEIPTS JOURNAL','CASH DISBURSEMENTS JOURNAL','GENERAL JOURNAL','GENERAL LEDGER','MONTHLY SUMMARY','SALES TRANSACTIONS']) {
  assert(excel.includes(`'${tab}'`), `Excel sheet missing: ${tab}`);
}
const accounting = source('lib/models/accounting_books.dart');
assert(accounting.includes('Sales settlement clearing') && accounting.includes('balanced'), 'Combined accounting journals missing');
const booksUi = source('lib/ui/accounting_books_page.dart');
for (const name of ['Cash Receipts Journal','Cash Disbursements Journal','General Journal','General Ledger']) {
  assert(booksUi.includes(name), `Missing accounting book view: ${name}`);
}
assert(source('lib/ui/home.dart').includes('Sales activity'), 'Sales dashboard missing');
assert(!source('lib/ui/hyperion_sidebar.dart').includes("_item('paymongo'"), 'Duplicate activity navigation remains');
assert(source('lib/ui/home.dart').includes('SalesImportService.select'), 'Generic sales file import missing');
assert(source('lib/services/sales_import_service.dart').includes('parseWorkbook'), 'Sales XLSX parser missing');
assert(source('lib/ui/home.dart').includes('TaxFilingPage'), 'Tax Filing navigation missing');
assert(source('lib/ui/home.dart').includes('HyperionSidebar'), 'Business sidebar missing');
assert(source('lib/ui/accounting_books_page.dart').includes('ScrollbarOrientation.bottom'), 'Horizontal Books scrollbar missing');
for (const route of ['tax-calendar','tax-monthly','tax-quarterly','tax-annual','tax-2307','tax-invoices','tax-books','journal','ledger','financial-reports','management-reports','aging-reports','purchase-records','business-assets','payroll','bulk-import']) {
  assert(source('lib/ui/hyperion_sidebar.dart').includes(route), `Sidebar route missing: ${route}`);
}
for (const excluded of ["_item('inbox'", "_item('help'"]) {
  assert(!source('lib/ui/hyperion_sidebar.dart').includes(excluded), 'Excluded menu item present');
}
for (const item of ['Calendar','Monthly','Quarterly','Annual','2307 Certificates','e-Invoicing','Books of Accounts']) {
  assert(source('lib/ui/tax_filing_page.dart').includes(item), `Missing tax section: ${item}`);
}
for (const tab of ['BUSINESS PROFILE','MASTER LISTS','COMPLIANCE TASKS']) {
  assert(excel.includes("'" + tab + "'"), "Excel business sheet missing: " + tab);
}
assert(source('lib/ui/home.dart').includes('BusinessInsightsPanel'), 'Dashboard insights missing');
assert(source('lib/ui/home.dart').includes('ExpenseCsvService.select'), 'Expense CSV import missing');
assert(source('lib/ui/home.dart').includes('openRecordSearch'), 'Global search missing');
const report = source('lib/models/reports.dart');
assert(report.includes('journalBalanced'), 'Double-entry accounting missing');
assert(source('web/index.html').includes('serviceWorker.register'), 'Offline app worker missing');
assert(source('web/index.html').includes('hyperionBooksLoader'), 'PWA-style runtime loader missing');
assert(source('lib/ui/home.dart').includes('HyperionLoading.whileRunning'), 'Operation loading hooks missing');
for (const icon of ['web/logo.png','web/favicon.png','web/apple-touch-icon.png','web/icons/Icon-192.png','web/icons/Icon-512.png']) {
  assert(existsSync(join(root, icon)), `Missing shared Hyperion PWA branding asset: ${icon}`);
}
assert(source('web/manifest.json').includes('"start_url": "."'), 'GitHub Pages subpath support missing');
console.log('PASS: local-first storage, picker, journal, Excel, JSON backup/restore, GitHub Pages subpath, offline shell.');
