#!/usr/bin/env bash
# Run Kaydo web against real Supabase (no mock).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.production ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.production
  set +a
fi

DATA_SOURCE="${DATA_SOURCE:-supabase}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-http://localhost:3847}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# Normalize common .env mistakes (spaces, doubled scheme).
SUPABASE_URL="$(echo "$SUPABASE_URL" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s#^https:https://#https://#; s#^http:http://#http://#')"
SUPABASE_ANON_KEY="$(echo "$SUPABASE_ANON_KEY" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

if [[ "$DATA_SOURCE" != "mock" ]]; then
  if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    echo "ERROR: Set SUPABASE_URL and SUPABASE_ANON_KEY (see deploy/SUPABASE_SETUP.md)."
    exit 1
  fi
  if [[ ! "$SUPABASE_URL" =~ ^https?:// ]]; then
    echo "ERROR: SUPABASE_URL must start with https:// (got: $SUPABASE_URL)"
    exit 1
  fi
fi

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

exec "${FLUTTER[@]}" run -d chrome --web-port=3847 \
  --dart-define=DATA_SOURCE="$DATA_SOURCE" \
  --dart-define=PUBLIC_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}"
