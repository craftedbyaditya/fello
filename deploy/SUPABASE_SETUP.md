# Supabase production setup (no mock data)

Kaydo defaults to **Supabase** at runtime. Mock is only for unit tests /
`--dart-define=DATA_SOURCE=mock`.

## 1. Create a Supabase project

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **New project** → pick org, name (e.g. `kaydo`), region, DB password
3. Wait until the project is ready

## 2. Apply schema (migrations)

**Do not run `supabase/seed.sql` in production** — that file is demo-only.

### Option A — SQL Editor (fastest)

1. Open **SQL → New query**
2. Paste and run, in order (safe to re-run; policies use `drop if exists`):
   - `supabase/migrations/20260324120000_init_fello.sql`
   - `supabase/migrations/20260324123000_onboarding_business_type.sql`
   - `supabase/migrations/20260324130000_profiles_select_own.sql`
   - `supabase/migrations/20260324140000_team_invites_employee_role.sql`
   - `supabase/migrations/20260324150000_subscription_plans.sql`
   - `supabase/migrations/20260324160000_rls_roles_and_public_submit_guards.sql`
   - `supabase/migrations/20260324170000_org_logo.sql`
   - `supabase/migrations/20260324171000_org_logo_storage.sql`
   - `supabase/migrations/20260324180000_lock_plans_and_submit_path.sql`
3. If earlier migrations already succeeded, skip those and run only the new ones.
4. Confirm tables exist under **Table Editor**: `organizations`, `profiles`, `organization_invites`, `forms`, `questions`, `responses`, `answers`, `submission_rate_limits`, `submission_dedupe`

### Option B — Supabase CLI

```bash
npm i -g supabase   # or brew install supabase/tap/supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

## 3. Auth URL config

**Authentication → URL configuration**

| Field | Value |
|-------|--------|
| Site URL | `https://kaydo.sayge.in` |
| Redirect URLs | `https://kaydo.sayge.in/**` and `http://localhost:3847/**` (for local) |

**Important for first launch:** **Authentication → Providers → Email** → turn **off** “Confirm email” while testing.  
If confirmations stay on, signup creates the user but returns no session — Kaydo will ask them to confirm email before signing in.

Password reset uses `/reset-password`. Keep that path under Redirect URLs (`https://kaydo.sayge.in/**`).

## 4. Copy API keys

**Project Settings → API**

- Project URL → `SUPABASE_URL` (e.g. `https://xxxxx.supabase.co` — one `https://`, no spaces)
- `anon` / `publishable` public key → `SUPABASE_ANON_KEY` (paste the full key)

## 5. Local env + run

```bash
cp .env.production.example .env.production
# fill SUPABASE_URL and SUPABASE_ANON_KEY

set -a && source .env.production && set +a

# Local against real Supabase:
fvm flutter run -d chrome --web-port=3847 \
  --dart-define=DATA_SOURCE=supabase \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PUBLIC_BASE_URL=http://localhost:3847
```

## 6. Production build (Hostinger)

```bash
set -a && source .env.production && set +a
./scripts/build_web.sh
```

Upload `build/web/*` to `public_html/kaydo` (see `deploy/HOSTINGER.md`).

## 7. Bot protection (Cloudflare Turnstile) — required for Supabase

Public `/f/...` submissions **must** go through the Edge Function after Turnstile.
Anon clients cannot call `submit_public_response` directly (revoked in
`20260324180000_lock_plans_and_submit_path.sql`).

1. Create a Turnstile widget (Managed challenge) for `kaydo.sayge.in`
2. Pass the **site key** into every Flutter build/run (required when `DATA_SOURCE=supabase`):

```bash
--dart-define=TURNSTILE_SITE_KEY="$TURNSTILE_SITE_KEY"
```

3. Deploy the Edge Function and set secrets:

```bash
supabase functions deploy submit-feedback
supabase secrets set TURNSTILE_SECRET_KEY=your_turnstile_secret
```

4. Confirm `TURNSTILE_SECRET_KEY` is set — without it the function returns 503.

**Subscription note:** `plan_id` cannot be changed by authenticated clients.
Paid entitlements stay locked until a payment webhook (service_role) is wired.

## 8. First real user (journey check)

1. Open `https://kaydo.sayge.in/sign-up`
2. Create an account (empty DB — no Harbor demo)
3. Complete onboarding (workspace name)
4. Create a survey → add questions → Publish
5. Open `/f/<slug>` and submit a response
6. Dashboard / reviews show that live data
7. Sign out → **Forgot password?** → open email link → set a new password
8. On a phone: open an invite link `/invite/<token>` and accept

## Checklist

- [ ] Migrations applied through `20260324180000_...` (no seed)
- [ ] Site URL + redirects set (include reset-password)
- [ ] `.env.production` filled (never commit) including `TURNSTILE_SITE_KEY`
- [ ] App built with `DATA_SOURCE=supabase` + Turnstile site key
- [ ] `submit-feedback` deployed with `TURNSTILE_SECRET_KEY`
- [ ] Hostinger upload + SSL
- [ ] Sign-up → onboarding → publish → public submit (with captcha) smoke-tested
- [ ] Password reset + mobile invite smoke-tested
- [ ] Confirm plan change from the app is rejected (Coming soon)
