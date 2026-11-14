#!/usr/bin/env bash
# Production web build for https://kaydo.sayge.in
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.production ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.production
  set +a
fi

PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://kaydo.sayge.in}"
DATA_SOURCE="${DATA_SOURCE:-supabase}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

# Normalize common .env mistakes (spaces, doubled scheme).
SUPABASE_URL="$(echo "$SUPABASE_URL" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s#^https:https://#https://#; s#^http:http://#http://#')"
SUPABASE_ANON_KEY="$(echo "$SUPABASE_ANON_KEY" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

if [[ "$DATA_SOURCE" == "supabase" ]]; then
  if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    echo "ERROR: Set SUPABASE_URL and SUPABASE_ANON_KEY for production builds."
    echo "Example:"
    echo "  SUPABASE_URL=https://xxxx.supabase.co \\"
    echo "  SUPABASE_ANON_KEY=eyJ... \\"
    echo "  ./scripts/build_web.sh"
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

echo "Building Kaydo web → $PUBLIC_BASE_URL (DATA_SOURCE=$DATA_SOURCE)"
"${FLUTTER[@]}" pub get
"${FLUTTER[@]}" build web --release --base-href=/ \
  --dart-define=DATA_SOURCE="$DATA_SOURCE" \
  --dart-define=PUBLIC_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}"

# Ensure CNAME is present for GitHub Pages / some CDNs.
echo 'kaydo.sayge.in' > build/web/CNAME

echo ""
echo "Build ready: $ROOT/build/web"
echo "Serve with SPA fallback to index.html, then point kaydo.sayge.in at the host."
