# Hyperion Books development guidance

This repository is Hyperion Books, a Flutter Web PWA. Preserve sales, imported PayMongo payout data, expenses, journals, ledgers, deduplication, and local-user data. Keep secrets and private financial records out of code and CI artifacts. Run existing Flutter tests and analysis before release.

## Graphify source navigation

Follow [the Graphify guide](docs/graphify.md) to create a local code-only map, and query it before broad code searches when present. Verify any graph result against current Dart code and tests; do not treat an outdated graph as evidence. The map excludes assets and data, and no hosted Graphify service is configured. If Graphify cannot run, work directly from source. Keep changes minimal and fully tested.

## UI/UX Pro Max — native repository skill

For interface, visual design, layout, accessibility, responsiveness, touch interaction, typography, and animation, read .agents/skills/ui-ux-pro-max/SKILL.md. Use its Python search script with react for Hyperion PWA, jetpack-compose for Android, and flutter for Hyperion Books. Preserve Hyperion branding and approved layouts. Do not use for purely backend changes.

The skill is pinned to the ui-ux-pro-max-cli@2.15.0 package, with local file hashes in .agents/upstream-lock.json. No app dependencies or automatic updates. From the repository root, use: python3 .agents/skills/ui-ux-pro-max/scripts/search.py "mobile navigation touch" --domain ux.
