# Hyperion Books — Quick start

This is an offline-first Flutter Web app. No Supabase or Google login is required.

1. Open the published PWA and select a date to add a PayMongo/Google Play payout or expense.
2. View the automatic Dashboard, Books, Journal and Ledger.
3. Use **Books → Excel** to export readable financial reports.
4. Use **Settings → Export JSON backup** regularly. This JSON is the only restorable backup format.
5. To move to another device, open the app there and select **Settings → Import JSON backup**. **It REPLACES all existing entries on that device**, after showing a preview and asking for confirmation.

## Getting it online

The repository contains `lib/`, `web/`, `scripts/`, `test/`, `.github/workflows/`, and `pubspec.yaml`. GitHub Actions builds and checks the project. For GitHub Pages, set Settings → Pages → Source: GitHub Actions, and create the Actions variable `ENABLE_GITHUB_PAGES=true` after checking your plan eligibility. GitHub Free cannot publish Pages from a private repo. The app uses `/hyperion-books/` as the default base path.

No database, backend, Google OAuth, secret API keys, or Supabase is involved. The published PWA site may be accessible to others; each browser keeps separate local records. Do not upload transaction files to your repo. Browser data can be deleted or evicted; back up often.
