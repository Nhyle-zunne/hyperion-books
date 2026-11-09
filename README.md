# Hyperion Books

A standalone **Flutter Web PWA** for private, simple PayMongo / Google Play payout tracking and expenses. The only regular entry forms are **Payout** and **Expense**. The overview, cash books, general journal, general ledger, monthly summary, and Excel `.xlsx` export are computed from those entries.

**Status: source-code deliverable, not a hosted/deployed app.** Flutter SDK and an authenticated Supabase project were not available in the authoring runtime, so compilation and live cloud/offline browser testing still need to be performed on your machine or through the included GitHub Actions CI. No changes have been applied to the Hyperion maritime reviewer or its Supabase database.

## What works in the source

- Mobile, tablet and desktop-responsive Flutter Web UI using Material 3.
- Real calendar popup via Flutter `showDatePicker` for payout/expense dates.
- PayMongo or Google Play dropdown; amount received; optional note; optional gross amount (deductions computed from gross − net).
- Expense date, description, peso amount and optional category.
- All money stored as **integer centavos** to avoid rounding errors.
- IndexedDB local-first records (`sembast_web`), so offline form changes are saved immediately.
- Google OAuth with Supabase and private, account-bound cloud data.
- Optimistic cloud revision / edit conflict detection: choose local or cloud copy instead of silent overwriting.
- Soft deletes (tombstones) carried across devices.
- Automatic cloud sync on save, app resume and every 4 minutes while open; manual Sync button.
- If the cloud session expires while offline, the last-used account's cached records remain usable on that **trusted device**; reconnect Google before cloud sync.
- Generated cash receipts, cash disbursements, general journal, general ledger and monthly summaries.
- Multi-sheet Excel `.xlsx` export (READ ME, PAYOUTS, EXPENSES, CASH RECEIPTS, CASH DISBURSEMENTS, GENERAL JOURNAL, GENERAL LEDGER, MONTHLY SUMMARY).
- Installable PWA manifest and a **custom service worker** that caches Flutter's compiled app shell including local CanvasKit.

## Important bookkeeping disclaimer

**A net payout is not necessarily gross revenue.** Payouts may represent accumulated sales, less fees, refunds, withholding and other adjustments. When gross is unknown, the app labels its income as *provisional payout receipts*. It does not manufacture invoice dates or numbers, nor certify these books as compliant BIR books. Keep payment-processor settlement statements, sales/invoice records and expense receipts for tax purposes, and reconcile gross collections separately.

## Set up your own cloud database (one-time)

Recommended: create a separate Supabase project for Hyperion Books, so it does not change your existing Hyperion reviewer.

1. Create a new Supabase project. Enable **Authentication → Providers → Google**. Add its OAuth client ID and secret per Supabase's dashboard instructions.
2. In Supabase's **SQL Editor**, run `supabase/migrations/20261109_hyperion_books_private.sql` once. The table is **read-only for authenticated clients with RLS**; all writes go through the authenticated `hyperion_books_save` function with server-side owner checking and optimistic `version` protection.
3. In **Authentication → URL Configuration**, set the Site URL to your eventual HTTPS app address (for example `https://books.your-domain.com`) and allow that address as an OAuth redirect. Add your exact development URL when testing, e.g. `http://localhost:4000`.
4. Get **Project URL** and **publishable key** (legacy `anon` key is compatible). These are public web-client configuration values. **Never put the service-role key** into Flutter source, `--dart-define`, or public hosting secrets.

## Run on a computer with Flutter installed

Requirements: recent stable Flutter SDK (recommended 3.50+), Dart 3.12+, Chrome, Node.js 20+.

```bash
flutter pub get
flutter run -d chrome --web-port 4000 \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The URL configured in Supabase's OAuth redirect allowlist must match the browser origin (including the port).

### Release build (offline PWA)

Mac/Linux/Git Bash:

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
bash scripts/build_web.sh
```

Windows PowerShell:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release --web-content-hash --no-web-resources-cdn --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
node scripts/make_sw.mjs build/web
Copy-Item web/_headers build/web/_headers -Force
```

Upload the **contents** of `build/web/` to a new static hosting project (e.g. *separate* Cloudflare Pages project). Host from the root of an HTTPS origin, with an SPA navigation fallback to `/index.html`. Preserve the original hashed files for one release during upgrades if possible. Do not replace `hyperionmaritime.org`'s existing maritime reviewer.

Flutter does not automatically generate a functioning caching service worker in current versions. `scripts/make_sw.mjs` uses the official `precache_manifest.json` produced by `--web-content-hash` to create `build/web/sw.js`. `--no-web-resources-cdn` includes CanvasKit locally for offline use. The initial online visit must finish the worker installation before offline reloads can work.

## Install on all devices

- Android: visit the HTTPS app in Chrome, choose **Install app** or **Add to Home screen**.
- iPhone / iPad: open in Safari, Share → **Add to Home Screen**.
- Windows / Mac: open in Edge/Chrome, choose **Install** from the browser's address bar or menu.
- One Google account owns the cloud entries; every device must initially open online and sign in. Devices keep **separate offline IndexedDB caches** that synchronize upon reconnecting.

**Offline caveats:** private browsing, clearing site data, changing the site domain, device storage eviction or PWA reinstallation can delete local entries. Sync before switching devices, and export Excel backups regularly. Offline local mode relies on trust in the physical/browser device; it is **not locally encrypted or protected by a separate PIN**. Avoid shared computers.

## Review and testing

After `flutter pub get`, run:

```bash
flutter analyze
flutter test
```

The included test suite checks integer-centavo parsing, balanced journal generation, gross/net deductions, month grouping, and edit identifiers. The CI workflow also builds a web release and generates the service worker with dummy configuration. On a deployed app, manually test:

1. Sign in, add a ₱700 PayMongo payout, add a ₱50 expense, and verify ₱650 net movement.
2. Turn off the internet; reopen the installed PWA; enter another expense, and verify it appears as pending.
3. Reconnect and sync; sign in on a second device; verify both entries arrive.
4. Edit the same item while each device is offline, then reconnect; verify the conflict choices appear (not silent overwrite).
5. Export `.xlsx`, open in Excel, confirm journal debits equal credits and entries match the app.
6. Sign out, then use a different Google account; no previous-account entries should appear.

## Privacy, import, and limitations

The user's prior Excel audit records are **not baked into the publicly distributed PWA bundle**. This avoids leaking private bookkeeping data to website visitors. Enter them privately after sign-in (or add a dedicated authenticated importer later).

This is a purpose-built starter app, not yet a production-audited accounting system. It does **not** automatically fetch transactions from PayMongo or Google Play, send invoices, compute taxes, back up encrypted local data, or distinguish tax-period sales from settlement dates. For BIR filing, use actual transaction documents and a qualified adviser when required.
