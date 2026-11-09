# Hyperion Books — Flutter Web PWA

**GitHub-only, local-first personal bookkeeping.** No Supabase, Google sign-in, external database, API token, or subscription required.

## Two things to enter

1. **Payout:** date (calendar picker), source (PayMongo or Google Play), net amount received; optional note and gross amount if supported by a settlement statement.
2. **Expense:** date (calendar picker), amount, description; optional category.

The app calculates monthly cashflow, cash receipts/disbursements, general journal, general ledger and Excel `.xlsx` books. Amounts use integer centavos rather than floating-point calculations.

## Privacy and transferring records

Entries are saved to browser **IndexedDB only on that device**. This is **not cloud sync**. To switch devices, use Settings → **Export JSON backup** and then Settings → **Import JSON backup** on the other device. Import previews totals and, after confirmation, **REPLACES the receiving device's records**; export its own backup first. Excel export is for reading/printing, **not restorable**; JSON is the restorable backup. Neither format is automatically uploaded to GitHub.

Keep JSON files somewhere safe and private, never in the source repository. Browser data cleanup, site origin changes, PWA removal or device loss may erase local entries. No device-side encryption is provided.

## Building and hosting

Requires Flutter stable **3.50+**, Dart, Node.js 20+:

```bash
flutter pub get
flutter analyze
flutter test
node scripts/check_source.mjs
bash scripts/build_web.sh
```

The default static build targets **`/hyperion-books/`** (GitHub Pages project path). For a dedicated root-domain host: `BASE_HREF=/ bash scripts/build_web.sh`. The build creates `build/web` and a custom offline service worker from Flutter's precache manifest.

### GitHub Pages and repository visibility

This repository is currently **private**. On **GitHub Free, Pages requires a public repository**. GitHub Pro/Team can publish Pages from private source repositories, but the published site is public. Never include personal financial records in the site bundle or repository.

If eligible, use Settings → Pages → Build and deployment → **GitHub Actions** and add a repository Actions variable `ENABLE_GITHUB_PAGES=true` to opt into the deployment workflow. The expected URL is `https://Nhyle-zunne.github.io/hyperion-books/`. Do not change repository visibility without reviewing the privacy implications.

## Current setup status

The full Flutter source is distributed separately as `Hyperion_Books_GitHub_Only_Source.zip` in the ChatGPT conversation. **The GitHub repository was initially missing the `lib/`, `web/`, `scripts/`, and `test/` source directories.** Upload the contents of the extracted ZIP **to the repository root**, preserving paths. GitHub Actions then runs compilation/tests. Do not assume the app is deployed just because the files are present.

## Important accounting note

Processor settlement dates are not necessarily sales dates. Net payouts may exclude fees, refunds, and withholding. Journal/ledger output is a provisional personal cash tracker, not automatically BIR-compliant official books.
