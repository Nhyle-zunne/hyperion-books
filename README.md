# Hyperion Books — Flutter Web PWA

**Business workflow update:** CPAlly-style management insights, local master lists, search, tax-task planner, bulk expense imports and private business profiles are included. See [Business workflows](docs/BUSINESS_WORKFLOWS.md) for scope and important accounting limitations.

Personal bookkeeping for sales, business payouts and expenses. **No Supabase, accounts, API tokens, or cloud database.** Hosted static app files do not contain financial entries.

## Books of Accounts and Tax Filing workspace

The Books tab now has four CPAlly-inspired report views with an inclusive covered-period filter, additional columns, selected-report Excel export and an offline-printable view. The **Tax Filing** navigation area includes Calendar, Monthly, Quarterly, Annual, 2307 Certificates, an invoice register, and a Books shortcut. Filing logs, manual invoice references and withholding certificate records are saved locally and included in backup and Excel export. See [Books and tax scope](docs/TAX_FILING_AND_BOOKS.md).

**Important:** This is a bookkeeping and preparation tool, not an official e-filing or e-invoicing service. The date planner is manual, forms are not submitted to BIR, and all accounting and tax amounts require verification.

## Basic records to enter

1. **Payout:** date (tap to select with a calendar), PayMongo or Google Play, net amount received, optional note and optional gross amount from a processor statement.
2. **Expense:** date (calendar), amount, description, and optional category.

Other views are generated: dashboard, 7/30/90-day business trends, monthly summary, cash receipts/disbursements, general journal, general ledger, and Excel `.xlsx` reports. Amounts are stored as integer centavos. Sales transactions can be imported as CSV or Excel files, and expenses through a separate CSV template with stable references.

## Where entries live

Each browser/PWA installation stores entries in **IndexedDB on that device**, accessible offline after the PWA shell is cached. **There is no automatic multi-device sync.** Each device has its own dataset. Use Settings → **Export JSON backup**, then Settings → **Import JSON backup** on another device to transfer the records. Import shows amounts and requires explicit confirmation because it **REPLACES** the target device's existing records. Export the receiving device's backup first! Excel exports are human-readable books and **cannot** be re-imported; the JSON file is the restorable backup.

Do not upload financial backups to GitHub. Neither IndexedDB nor the unencrypted JSON backup uses at-rest encryption. Use a device with a screen lock, keep backups in a private location, and make regular backups; clearing browser site data or losing the device may erase local records.

## GitHub Pages hosting

GitHub currently reports `hyperion-books` as a **public repository**. GitHub Free requires a public repo for GitHub Pages; Pro/Team can also publish from private repos. With GitHub Pro/Team, you can publish from private repos, but **the published site is still publicly accessible**. Never commit private bookkeeping data even if the repo is private. GitHub Pages is static hosting, not a financial database.

If your plan supports Pages from this repo, use **Settings → Pages → Build and deployment → GitHub Actions**, and set repository **Settings → Secrets and variables → Actions → Variables → `ENABLE_GITHUB_PAGES` = `true`**. The `pages.yml` workflow then builds and publishes `https://<owner>.github.io/hyperion-books/`. If the repository becomes private on GitHub Free, Pages publishing from it will not be available; review the repo visibility and plan before turning deployment on. **No user financial data should ever be committed to the repository.**

## Build locally

Requires a recent stable Flutter SDK (current stable), Dart and Node.js 20+.

```bash
flutter pub get
flutter analyze
flutter test
node scripts/check_source.mjs
bash scripts/build_web.sh
```

By default it builds for the GitHub Pages subpath `/hyperion-books/`. For a dedicated domain root use `BASE_HREF=/ bash scripts/build_web.sh`. The script produces `build/web` and generates `sw.js` by enumerating the compiled static assets; no credentials or environment secrets are required.

The app runs on Android, iPhone/iPad, Windows, and Mac through an HTTPS browser and can be installed as a PWA. Install while online, wait for the service worker to cache the app, then test offline. iOS browsers may evict app storage; back up regularly.

## Verification status

`flutter analyze`, `flutter test`, and a web build run in `.github/workflows/flutter.yml` on pushes and pull requests. **CI results must be checked** before considering a change tested. GitHub Pages publishing is opt-in and may be unavailable on a private GitHub Free repository.

## Accounting caveat

Processor payouts may include sales from earlier dates and differ from gross sales because of fees, refunds, withholding, or other adjustments. This app records net cash movement and provisional journals; the reports are not independently certified BIR books of accounts or automatically tax-compliant. Keep underlying statements and receipts.

## Shared Hyperion branding

The browser tab, home-screen icons and startup/operation loader reuse the exact gold/navy logo assets from `hyperion-pwa`. The cube loader uses the same six faces, 2.4-second rotation, progress sweep and reduced-motion behavior. The loader is visual-only: no financial data leaves the device.

## Sales imports — CSV and Excel

Open **Sales** → **Import Sales CSV / Excel** to import customer sales from a business spreadsheet. The Sales page is provider-neutral. The former duplicate activity menu item has been removed. A downloadable **Sales CSV template** contains these columns:

`Reference,Date,Gross Amount,Fee,Fee VAT,Net Amount,Status,Payment Method,Type,Currency`

- **Required:** unique stable Reference, transaction Date/time and Gross Amount. Use YYYY-MM-DD HH:MM. The same reference imported again (even in a renamed or reordered file) is skipped, while changed existing records are flagged without overwriting.
- **Optional:** fees, the VAT already included in the fee, net amount, status, payment method, transaction type and currency. Only PHP is accepted. The app calculates net when omitted and rejects mismatched gross/fee/net totals.
- **Formats:** ordinary `.csv` or Excel `.xlsx` (up to 12 MB). Excel cells with formulas are rejected; paste values before importing. The first nonempty worksheet is used. Existing processor-specific Transactions CSV files are still supported without showing their branding in the Sales UI.
- **Preview:** paid sales, adjustments/refunds, skipped unpaid rows, already imported references and conflicts are shown before saving. Financial imports stay local to the browser.
- **Accounting:** imported sales create provisional source records and journal postings, not bank deposits. Record each actual bank transfer once under **Entries**. Processing-fee VAT is already included in the total fee and must not be subtracted again.

Sales CSV/XLSX importing is distinct from **Export Excel books**. The full exported accounting workbook is a report, not a restorable JSON backup. To transfer your complete dataset to another device, use JSON backup/restore.

Do not commit customer transaction data or financial backups to the public repository.

## Four accounting books and BIR scope

The Books page and Excel export contain **Cash Receipts Journal**, **Cash Disbursements Journal**, **General Journal** and **General Ledger**, populated from imported sales and manually entered bank payouts and expenses. They are provisional working records, **not automatically compliant or BIR-registered computerized books**. The [accounting and BIR scope](docs/ACCOUNTING_AND_BIR_SCOPE.md) documents the classification assumptions, official BIR references, and missing data that must be reconciled against invoices and bank statements before formal use.

## New business tools and bulk expense CSV import

The **Tools** tab includes a local business profile, customer/vendor/product and expense-category master lists, a manually maintained tax and compliance task planner with date pickers, and your existing backup/export functions. The global search button finds local sales, payout, expense, list and task records; the top-bar + button provides quick entry/import actions. The dashboard shows management trends, costs by category, recent sales and expenses, and bank cash movement. These are not audited financial statements or verified taxable gross sales.

For expenses, choose **Import expenses CSV** from Entries, Tools or Quick Record. Download the template from Tools. The CSV must have `Reference,Date,Amount,Description,Category` (Category optional). Each expense needs a unique stable Reference; reimporting the same IDs skips existing records. Different genuine expenses should have different references even when dates and amounts match. All imports happen in your browser.

A JSON backup now uses schema version 3 and includes the business profile, lists and reminders. Backups from v1/v2 remain importable, but importing an old backup **replaces all local records and resets the new business workspace** because it has no such data. Export your current backup before restoring anything. Excel exports include separate business-list and task sheets which may contain private information.

**Not yet implemented:** automated BIR submissions/forms or statutory DATs, real-time inventory/receivables, OCR invoice scanning, automatic tax deadlines, multi-business accounting, shared cloud data, or live bank feeds. Those require further work and potentially a backend.
