#!/usr/bin/env bash
set -euo pipefail
./scripts/build_web.sh
version="$(awk '/^version:/ {print $2}' pubspec.yaml)"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > build/web/release.json <<EOF
{"version":"$version","commit":"${GITHUB_SHA}","run_id":"${GITHUB_RUN_ID}","built_at":"$timestamp"}
EOF
