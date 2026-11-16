#!/usr/bin/env bash
set -euo pipefail
umask 077
key_file="$(mktemp)"
trap 'rm -f "$key_file"' EXIT
printf '%s\n' "$HOSTINGER_SSH_PRIVATE_KEY" > "$key_file"
release_id="${GITHUB_SHA:0:12}"
relative_root="$HOSTINGER_DOCUMENT_ROOT"
[[ "$relative_root" == '/public_html/kaydo' ]] || { echo 'Refusing non-Kaydo deployment path' >&2; exit 1; }
port="${HOSTINGER_SSH_PORT:-65002}"
ssh_opts=(-i "$key_file" -p "$port" -o StrictHostKeyChecking=yes)
mkdir -p "$HOME/.ssh"
printf '%s\n' "$HOSTINGER_SSH_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
# Resolve the account-specific absolute path remotely and reject anything that
# is not exactly the known Kaydo root. Never operate on app.sayge.in or root web.
live_root="$(ssh "${ssh_opts[@]}" "$HOSTINGER_SSH_USER@$HOSTINGER_SSH_HOST" "cd \"\$HOME$relative_root\" && pwd -P")"
# This is the account-specific canonical path supplied by hPanel. A suffix
# comparison could accept another account or domain with the same directory
# name; deployment must stop unless it is this exact Kaydo web root.
expected_live_root='/home/u439432935/domains/sayge.in/public_html/kaydo'
[[ "$live_root" == "$expected_live_root" ]] || { echo 'Resolved Hostinger path is not the verified Kaydo root' >&2; exit 1; }
parent="${expected_live_root%/public_html/kaydo}"
staging="$parent/.kaydo-staging/$release_id"
backup="$parent/.kaydo-backups/$release_id"
ssh "${ssh_opts[@]}" "$HOSTINGER_SSH_USER@$HOSTINGER_SSH_HOST" "mkdir -p '$staging' '$backup'"
tar -C build/web -czf - . | ssh "${ssh_opts[@]}" "$HOSTINGER_SSH_USER@$HOSTINGER_SSH_HOST" "tar -xzf - -C '$staging'"
ssh "${ssh_opts[@]}" "$HOSTINGER_SSH_USER@$HOSTINGER_SSH_HOST" "test -f '$staging/index.html' && test -f '$staging/.htaccess'"
# Hostinger serves the fixed document root, so this is deliberately not atomic:
# archive the current root, then overwrite managed files in place. No deletion.
ssh "${ssh_opts[@]}" "$HOSTINGER_SSH_USER@$HOSTINGER_SSH_HOST" "tar -czf '$backup/site.tar.gz' -C '$live_root' . && tar -C '$staging' -cf - . | tar -xf - -C '$live_root'"
