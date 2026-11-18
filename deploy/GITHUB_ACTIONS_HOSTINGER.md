# GitHub Actions → Hostinger production deployment

The frontend workflow deploys **only** after a trusted push to `main`, uses the
GitHub Environment named `production`, and never changes Supabase.

## hPanel setup

1. Kaydo's confirmed hPanel-relative document root is `/public_html/kaydo`.
   It remains the live root; do not change it to a symlink or `/public_html`.
2. If SSH is available, create a deploy-only SSH user/key restricted to the
   hosting account and port `65002`.
3. Enable HTTPS and verify DNS resolves only `kaydo.sayge.in` to this hosting
   account. Confirm Apache serves `current/.htaccess`.

## GitHub Environment: `production`

Create an environment called `production` and require reviewer approval for
deployments. Add these **variables** (browser-safe values):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `TURNSTILE_SITE_KEY`
- `HOSTINGER_DOCUMENT_ROOT` — exactly `/public_html/kaydo`
- `HOSTINGER_SSH_PORT` — `65002` (optional; script defaults to this value)

Add these **secrets**:

- `HOSTINGER_SSH_HOST`
- `HOSTINGER_SSH_USER`
- `HOSTINGER_SSH_PRIVATE_KEY`
- `HOSTINGER_SSH_KNOWN_HOSTS` — pre-verified `known_hosts` entry from hPanel/Hostinger support; do not generate it in CI

Do not add service-role, Turnstile secret, AI, database, or Supabase CLI
credentials. They do not belong in a browser deployment workflow.

## Release and rollback

## Automatic versioning and deployment

After this workflow is enabled, merging a PR to `main` is the release action:

1. GitHub Actions runs Flutter tests and analysis.
2. `scripts/bump_version.dart` increments `pubspec.yaml` and creates a
   `chore(release): vX.Y.Z+N` commit on `main`.
3. The same workflow builds that release commit and deploys it to Hostinger.

Use Conventional Commit-style PR titles when squash merging:

- `fix: …` (or any unrecognised title) → patch release
- `feat: …` → minor release
- `feat!: …` or a title/body containing `BREAKING CHANGE` → major release

No AI model is required. A Mac can calculate a version locally with:

```bash
dart run scripts/bump_version.dart --level patch
```

That command edits `pubspec.yaml`; use it only when intentionally preparing a
manual release. Normal releases are performed by the GitHub workflow after a
PR merge.

### One-time GitHub setup

The `github-actions[bot]` must be able to create the release commit on `main`.
In the repository's **Actions → General** settings, select **Read and write
permissions** for workflows. If branch protection prevents this push, allow
only GitHub Actions (or a dedicated GitHub App bot) to bypass the required
status-check restriction. Do not weaken required reviews for human users.

The `production` environment remains the deployment gate. Its required
reviewers, SSH secrets, and path restrictions are unchanged.

Each deployment resolves the real SSH path for `/public_html/kaydo`, stages the
artifact in `$HOME/.kaydo-staging/<commit>`, and archives the live root in
`$HOME/.kaydo-backups/<commit>/site.tar.gz` before copying files into the fixed
live directory. `release.json` contains package version, commit, Actions run
ID, and UTC build timestamp. To roll back, extract the desired backup archive
into `/public_html/kaydo` over SSH and verify `/`, `/dashboard`, and a public
`/f/<slug>` URL. This deployment is **not atomic**: Hostinger's fixed document
root prevents a symlink switch, and visitors may briefly receive mixed assets.
No broad deletion or `rsync --delete` is used. A frontend rollback never
reverses database migrations.

## SFTP fallback

If hPanel SSH is unavailable, do not enable the SSH workflow. Use a restricted
SFTP account rooted at the Kaydo subdomain and manually upload the built Actions
artifact after backing up the current document root. This replacement is not
atomic; preserve `.htaccess`, verify all Flutter assets upload, and keep the
previous artifact for rollback.

## Backend releases

Database migrations, Edge Functions, Auth settings, flags, and subscriptions
are separate approval-based operations. This workflow must never run Supabase
CLI deployment commands.
