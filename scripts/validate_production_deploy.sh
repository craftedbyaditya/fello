#!/usr/bin/env bash
set -euo pipefail
for name in SUPABASE_URL SUPABASE_ANON_KEY TURNSTILE_SITE_KEY HOSTINGER_DOCUMENT_ROOT HOSTINGER_SSH_HOST HOSTINGER_SSH_USER HOSTINGER_SSH_PRIVATE_KEY HOSTINGER_SSH_KNOWN_HOSTS; do
  if [[ -z "${!name:-}" ]]; then echo "Missing required production configuration: $name" >&2; exit 1; fi
done
[[ "$SUPABASE_URL" =~ ^https:// ]] || { echo 'SUPABASE_URL must use HTTPS' >&2; exit 1; }
[[ "$HOSTINGER_DOCUMENT_ROOT" == '/public_html/kaydo' ]] || { echo 'HOSTINGER_DOCUMENT_ROOT must be exactly /public_html/kaydo' >&2; exit 1; }
port="${HOSTINGER_SSH_PORT:-65002}"
[[ "$port" =~ ^[0-9]+$ ]] && (( port > 0 && port < 65536 )) || { echo 'Invalid HOSTINGER_SSH_PORT' >&2; exit 1; }
