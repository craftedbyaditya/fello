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
APP_VERSION="${APP_VERSION:-$(awk '/^version:/ {print $2}' pubspec.yaml)}"
APP_VERSION="${APP_VERSION%%+*}"

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
"${FLUTTER[@]}" build web --release --base-href=/ --pwa-strategy=none \
  --dart-define=DATA_SOURCE="$DATA_SOURCE" \
  --dart-define=PUBLIC_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-}" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}"

# Ensure CNAME is present for GitHub Pages / some CDNs.
echo 'kaydo.sayge.in' > build/web/CNAME

# Flutter's entry files have stable names. Version their URLs per release so
# Hostinger's CDN cannot serve an older application bundle after a deploy.
release_token="${GITHUB_SHA:-local}"
release_token="${release_token:0:12}"
python3 - "$release_token" <<'PY'
from pathlib import Path
import sys

token = sys.argv[1]
bootstrap = Path('build/web/flutter_bootstrap.js')
text = bootstrap.read_text()
needle = 'mainJsPath":"main.dart.js"'
if needle not in text:
    raise SystemExit('Unable to version Flutter main entrypoint')
bootstrap.write_text(text.replace(needle, f'mainJsPath":"main.dart.js?v={token}"', 1))

index = Path('build/web/index.html')
text = index.read_text()
needle = '<script src="flutter_bootstrap.js" async></script>'
if needle not in text:
    raise SystemExit('Unable to version Flutter bootstrap entrypoint')
replacement = '''<script>
    // Kaydo does not offer offline mode. Retire workers left by older Flutter
    // builds before loading this release's cache-busted bootstrap.
    const loadKaydo = () => {
      const script = document.createElement('script');
      script.src = 'flutter_bootstrap.js?v=%s';
      script.async = true;
      document.body.appendChild(script);
    };
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations()
        .then((registrations) => Promise.all(registrations.map((r) => r.unregister())))
        .catch(() => {})
        .finally(loadKaydo);
    } else {
      loadKaydo();
    }
  </script>''' % token
index.write_text(text.replace(needle, replacement, 1))
PY

echo ""
echo "Build ready: $ROOT/build/web"
echo "Serve with SPA fallback to index.html, then point kaydo.sayge.in at the host."
