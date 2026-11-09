# Hyperion Books — Flutter Web PWA

Personal bookkeeping for PayMongo and Google Play payouts, and expenses. **No Supabase, accounts, API tokens, or cloud database.** Hosted static app files do not contain financial entries.

## Two things to enter

1. **Payout:** date (tap to select with a calendar), PayMongo or Google Play, net amount received, optional note and optional gross amount from a processor statement.
2. **Expense:** date (calendar), amount, description, and optional category.

All other views are generated: dashboard, monthly summary, cash receipts/disbursements, general journal, general ledger, and Excel `.xlsx` reports. Amounts are stored as integer centavos.

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

## PayMongo transaction CSV import

Open **PayMongo** → **Import PayMongo CSV** and select a transaction report
from PayMongo. A preview shows new successful payments, adjustments/refunds,
unsupported statuses and duplicates before any records are saved.

- Import records retain the exported **date and time** and are sortable newest
  or oldest first. No timezone conversion is assumed.
- Re-imported Transaction IDs are skipped; overlapping CSV reports do not
  double-count. Names, emails, phone numbers and billing addresses are not saved.
- **Transactions are not bank payouts.** Successful imported payments are now
  included in dashboard sales activity and draft accounting working papers:
  debit PayMongo clearing, debit fees (including VAT), credit provisional gross sales.
  A later bank payout entered in Entries is instead a transfer from PayMongo
  clearing to the bank, not a second sale. Refunds/adjustments require review.
  Record actual bank transfers once in Entries → Add payout, dated when the
  funds are received. Expenses remain manual.
- The PayMongo Fee column includes its VAT portion; the VAT column is shown for
  reference and is not deducted a second time.
- JSON backups now include imported transactions. Existing v1 backups remain
  supported; restoring a backup replaces all local cash entries and imported
  transactions only after a confirmation prompt.

Do not commit private transaction CSVs or financial backups into this repository.

## Four accounting books and BIR scope

The Books page and Excel export now contain separately named **Cash Receipts Journal**, **Cash Disbursements Journal**, **General Journal** and **General Ledger**, each populated from imported PayMongo customer payments and/or manual bank payouts and expenses as appropriate. They are provisional working records, **not automatically compliant or BIR-registered computerized books**. The [accounting and BIR scope](docs/ACCOUNTING_AND_BIR_SCOPE.md) documents the classification assumptions, official BIR references, and missing data that must be reconciled against invoices and bank statements before formal use.
