# Hyperion Books — Start here

This is a Flutter Web PWA with **no Supabase or Google sign-in**.

1. Download and extract `Hyperion_Books_GitHub_Only_Source.zip` from the ChatGPT conversation.
2. Upload **all contents** of the extracted folder to the GitHub repository root (not the ZIP alone, not inside an extra parent directory).
3. The Flutter source needs `lib/`, `web/`, `scripts/`, `test/`, `docs/`, `pubspec.yaml` and `.github/workflows/`.
4. Check the GitHub Actions build for successful `flutter analyze`, `flutter test`, and web build.
5. To host on GitHub Pages, you must be eligible to publish from this repo. GitHub Free requires a public repository; the current repository is private.
6. If eligible: Settings → Pages → Source: GitHub Actions. Settings → Secrets and variables → Actions → Variables: `ENABLE_GITHUB_PAGES=true`. No secrets are needed.
7. Once published: add payouts or expenses (calendar picker), view generated books, and export Excel. Export a **JSON backup** often for recovery and transfer. Import **REPLACES** all records on that device after confirmation.

No automatic multi-device synchronization. Records stay in each device's browser storage. Never upload private financial backups to GitHub.
