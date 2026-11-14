# Hyperion Books development guidance

This repository is Hyperion Books, a Flutter Web PWA. Preserve sales, imported PayMongo payout data, expenses, journals, ledgers, deduplication, and local-user data. Keep secrets and private financial records out of code and CI artifacts. Run existing Flutter tests and analysis before release.

## Graphify source navigation

Follow [the Graphify guide](docs/graphify.md) to create a local code-only map, and query it before broad code searches when present. Verify any graph result against current Dart code and tests; do not treat an outdated graph as evidence. The map excludes assets and data, and no hosted Graphify service is configured. If Graphify cannot run, work directly from source. Keep changes minimal and fully tested.
