# Hyperion Books — Start here

This is a standalone Flutter **Web PWA source project**, not an installed or hosted application.

## What you will use

1. Open the app on your phone or PC, sign in once with Google while online.
2. Add a **PayMongo** or **Google Play** payout with date and amount.
3. Add an **expense** with date, amount and description.
4. The **Dashboard, Cash Books, General Journal, General Ledger, and monthly summary** generate automatically.
5. Open **Books → Excel** to download an `.xlsx` backup.
6. Once initially loaded online, the PWA shell and IndexedDB records work offline. Later sign-ins and syncing need an internet connection.

## To go live

A developer or a computer with Flutter 3.50+ (Dart 3.12+) must:

1. Install Flutter, Chrome, and Node.js 20+. Run `flutter doctor` to verify.
2. In the project folder, run `flutter pub get`, `flutter analyze`, `flutter test`.
3. Create a **new** Supabase project for Hyperion Books and enable Google OAuth in its Auth settings. Configure its Site URL and redirect allowlist for your app domain.
4. Run `supabase/migrations/20261109_hyperion_books_private.sql` in the new project's SQL Editor.
5. Build with your project's **public** URL and publishable key (not any secret/service-role key):

   **Windows PowerShell**:
   ```powershell
   flutter build web --release --web-content-hash --no-web-resources-cdn --dart-define="SUPABASE_URL=https://YOUR-PROJECT.supabase.co" --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY"
   node scripts/make_sw.mjs build/web
   Copy-Item web/_headers build/web/_headers -Force
   ```

   **macOS/Linux (bash)**:
   ```bash
   export SUPABASE_URL=https://YOUR-PROJECT.supabase.co
   export SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY
   bash scripts/build_web.sh
   ```

6. Upload the **contents** of `build/web/` to a fresh HTTPS hosting site (for example a new Cloudflare Pages project). Do not replace the existing Hyperion reviewer app. Configure SPA route fallback and cache-control headers.
7. Visit the site once online, allow it to finish loading, then install it from the browser menu.

For more details read `README.md` and `docs/SECURITY_AND_SYNC.md`.

## Tests performed for this delivery

- JavaScript syntax check on `scripts/make_sw.mjs`.
- Service-worker generation with a synthetic Flutter 3.50-style precache manifest.
- Static verification of date picker, payout/expense forms, journal, seven Excel sheets, private RLS and account-bound RPC, IndexedDB storage and revision-conflict guards.

**Not yet performed:** `flutter analyze`, `flutter test`, actual Flutter production compilation, connected Supabase tests, two-device sync tests, or a live PWA offline-browser test. Do these before entering important financial records.

## Accounting note

Net payouts are cash receipts for personal tracking, **not necessarily gross sales** for tax reporting. The generated journal and ledger are provisional, not automatically BIR-compliant official books.
