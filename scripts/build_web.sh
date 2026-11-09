#!/usr/bin/env bash
set -euo pipefail
# GitHub project Pages URL: https://OWNER.github.io/hyperion-books/
# Set BASE_HREF=/ to host at a dedicated domain root instead.
BASE_HREF="${BASE_HREF:-/hyperion-books/}"
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --base-href="$BASE_HREF"
node scripts/make_sw.mjs build/web
printf 'Static, fully local PWA ready at build/web; no credentials required.\n'
