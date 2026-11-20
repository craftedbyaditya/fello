#!/usr/bin/env bash
# Regression coverage for direct, symlink, wrapper, and outside-directory CLI use.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/bin" "$TEMP_ROOT/outside"

cat >"$TEMP_ROOT/bin/fvm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == 'flutter analyze' || "$1 $2" == 'flutter test' ]]; then
  echo "mock $2 passed"
  exit 0
fi
exit 99
EOF
chmod +x "$TEMP_ROOT/bin/fvm"
ln -s "$ROOT/scripts/kaydo" "$TEMP_ROOT/kaydo-symlink"
cat >"$TEMP_ROOT/kaydo-wrapper" <<EOF
#!/usr/bin/env bash
exec "$ROOT/scripts/kaydo" "\$@"
EOF
chmod +x "$TEMP_ROOT/kaydo-wrapper"

assert_log_root() {
  local newest
  newest="$(ls -t "$ROOT/.kaydo/logs"/check-*.log | head -1)"
  grep -Fq "Repository: $ROOT" "$newest"
}

run_check_from_outside() {
  local command="$1"
  (
    cd "$TEMP_ROOT/outside"
    PATH="$TEMP_ROOT/bin:$PATH" "$command" check >/dev/null
  )
  assert_log_root
}

run_check_from_outside "$ROOT/scripts/kaydo"
run_check_from_outside "$TEMP_ROOT/kaydo-symlink"
run_check_from_outside "$TEMP_ROOT/kaydo-wrapper"

# `status` must identify the verified root even when its caller is elsewhere.
status_output="$(cd "$TEMP_ROOT/outside" && "$TEMP_ROOT/kaydo-symlink" status)"
grep -Fq "Repository: $ROOT" <<<"$status_output"

# A copied entrypoint outside the repository must fail before it can run Git in
# the caller's directory or create an unrelated .kaydo log directory.
cp "$ROOT/scripts/kaydo" "$TEMP_ROOT/unrelated-kaydo"
chmod +x "$TEMP_ROOT/unrelated-kaydo"
if (cd "$TEMP_ROOT/outside" && "$TEMP_ROOT/unrelated-kaydo" help >/dev/null 2>&1); then
  echo 'unrelated repository safety check unexpectedly succeeded' >&2
  exit 1
fi

echo 'kaydo CLI path regression tests passed'
