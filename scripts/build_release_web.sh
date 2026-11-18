#!/usr/bin/env bash
set -euo pipefail
./scripts/build_web.sh
version="$(awk '/^version:/ {print $2}' pubspec.yaml)"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > build/web/release.json <<EOF
{"version":"$version","commit":"${GITHUB_SHA}","run_id":"${GITHUB_RUN_ID}","built_at":"$timestamp"}
EOF

# The deploy script verifies this manifest after copying to the fixed Hostinger
# document root. It covers the browser entrypoints and release metadata rather
# than relying on a successful SSH command as proof that the active bundle is
# the one built by this GitHub Actions run.
(
  cd build/web
  sha256sum index.html flutter_bootstrap.js main.dart.js release.json > release.sha256
)
