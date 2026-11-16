# Kaydo

Kaydo helps organisations collect feedback through shareable forms (web link + QR). Customers submit without an account. Organisations get a dashboard with filters and charts.

## Stack

- Flutter (web-first, responsive)
- BLoC architecture + go_router
- Supabase schema/migrations (optional at runtime)
- Mock data layer by default for fast local demos

## Quick start (Supabase — production path)

Kaydo defaults to **real Supabase data** (no mock).

1. Follow **`deploy/SUPABASE_SETUP.md`** (create project, run migrations, copy keys).
2. Configure env and run:

```bash
cp .env.production.example .env.production   # fill URL + anon key
./scripts/run_web.sh
```

Sign up a real user → create surveys → publish → collect responses.

Mock is opt-in only for tests: `--dart-define=DATA_SOURCE=mock`.

## Run with Android Studio / Cursor Play button

1. **Open the project root** (`fello/`) in Android Studio (Flutter plugin) or Cursor.
2. Set Flutter SDK to FVM (Android Studio → Settings → Languages & Frameworks → Flutter):
   - SDK path: `fello/.fvm/flutter_sdk` (or your FVM 3.47.9 path).
3. Select device **Chrome** (web).
4. Choose a run configuration:
   - **Kaydo Web (mock)** — works immediately (no keys).
   - **Kaydo Web (supabase)** — copy config first:

```bash
cp config/dart_defines.supabase.json.example config/dart_defines.supabase.json
# edit SUPABASE_URL, SUPABASE_ANON_KEY, TURNSTILE_SITE_KEY
```

5. Press **Run / Play**.

Configs live in `.idea/runConfigurations/` (Android Studio) and `.vscode/launch.json` (Cursor/VS Code).

## Project layout

- `lib/domain` — entities + repository contracts
- `lib/data/mock` / `lib/data/supabase` — implementations
- `lib/features` — auth, onboarding, forms, dashboard, public_form
- `supabase/migrations` — source of truth for schema + RLS
- `.cursor/skills` + `.cursor/agents` — SQL sync and feature/test agents

## Agent / skill workflow

When a requirement changes persistence, follow `AGENTS.md` and `.cursor/skills/fello-supabase-sync/SKILL.md` so migrations, seed, mock, and supabase code stay aligned.

## Tests

```bash
flutter test
flutter analyze
```

## Deploy to kaydo.sayge.in

Production origin: **https://kaydo.sayge.in**  
Public form links look like `https://kaydo.sayge.in/f/<slug>` (path URLs + SPA rewrite).

### 1. Build

```bash
cp .env.production.example .env.production   # fill Supabase values
set -a && source .env.production && set +a
./scripts/build_web.sh
```

Output: `build/web/`

### 2. DNS

At your DNS for `sayge.in`, create:

| Type  | Name  | Value                          |
|-------|-------|--------------------------------|
| CNAME | kaydo | your host target (or A record) |

Examples: Vercel/Netlify/Cloudflare Pages assigned hostname, or your nginx box IP.

### 3. Hosting (pick one)

Upload / connect **`build/web`** and keep SPA fallback to `index.html`:

- **Hostinger (recommended for sayge.in)** — step-by-step: `deploy/HOSTINGER.md` (uses `web/.htaccess`)
- **Nginx** — sample vhost: `deploy/nginx.kaydo.sayge.in.conf`
- **Vercel** — root `vercel.json` rewrites; deploy the `build/web` output
- **Firebase Hosting** — `firebase.json` already points at `build/web`
- **Netlify / Cloudflare Pages** — `web/_redirects` is copied into the build

### 4. Supabase Auth

In the Supabase project → Authentication → URL configuration:

- **Site URL:** `https://kaydo.sayge.in`
- **Redirect URLs:** `https://kaydo.sayge.in/**`

Also allow the origin in any CORS / allowed hosts settings you use.

### 5. Smoke check

- `https://kaydo.sayge.in/sign-in`
- Soft refresh on `/dashboard` (must not 404)
- Published form: `https://kaydo.sayge.in/f/<slug>`
- QR / share link uses `PUBLIC_BASE_URL=https://kaydo.sayge.in`

## Local path

This repository is the Kaydo/Sayge project. Clone it to `/Users/adityarana/Code/Sayge` (or any path) on your machine.
