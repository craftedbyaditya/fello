# Kaydo local developer CLI

`scripts/kaydo` is a small, local-only wrapper around the repository's existing
tooling. It resolves symlinks before locating the repository, so a symlink at
`~/.local/bin/kaydo` works from any directory. It has no command that deploys,
applies a migration, resets a database, commits, merges, or force-pushes.

## Install

From the repository root:

```bash
chmod +x scripts/kaydo scripts/kaydo_lm.py
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/scripts/kaydo" "$HOME/.local/bin/kaydo"
```

Ensure `$HOME/.local/bin` is on your `PATH` (for zsh, add
`export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc`). The script resolves its
own repository path, so it works from any current directory.

Or run it without installing:

```bash
./scripts/kaydo help
```

## Commands

| Command | Purpose |
| --- | --- |
| `kaydo check` | Runs `fvm flutter analyze` and `fvm flutter test`; keeps full output. |
| `kaydo build` | Delegates to `scripts/build_web.sh`; it validates required browser-safe configuration. |
| `kaydo db-check` | Read-only comparison of local migration filenames and Supabase remote history. It never repairs or applies migrations. |
| `kaydo status` | Shows branch, commit, working tree, related PR, and recent Actions runs. |
| `kaydo pr` | Requires a feature branch and literal `PUSH` confirmation, then creates a draft PR. It does not stage, commit, or merge. |
| `kaydo explain [--file PATH] [--model ID]` | Sends a bounded, redacted local log to LM Studio for an optional explanation. |
| `kaydo pr-draft [--model ID]` | Produces proposed PR text from a bounded, redacted local diff. It never pushes or creates a PR. |

Raw logs are stored at `.kaydo/logs/` and are ignored by Git. Read them before
relying on a model summary.

## LM Studio

Start LM Studio's local server at `http://127.0.0.1:1234/v1` and load a model.
The CLI discovers model IDs through `/v1/models`; use `--model` to override the
first loaded model. All text stays on `127.0.0.1`, is redacted before sending,
and model output is advisory—not verified evidence or executable instructions.

If LM Studio is not running, only `explain` and `pr-draft` fail. The deterministic
commands remain available.

## Database safety

`db-check` expects production project `wpqazaqbxuwoarouwphy` and invokes only:

```bash
supabase migration list --remote --output json
```

It returns nonzero when access is unavailable or history is divergent. Resolve
that manually through a reviewed migration plan; do not use the CLI to repair
history.

## Production verification

GitHub Actions success is CI/deployment automation evidence, not a guarantee
that the public app is correct. Verify the actual deployment separately in a
fresh browser session and through intended production smoke tests.
