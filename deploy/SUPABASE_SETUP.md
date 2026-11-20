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
   - `supabase/migrations/20260324190000_ai_feedback_workflow.sql`
   - `supabase/migrations/20260324191000_form_deleted_status.sql`
3. If earlier migrations already succeeded, skip those and run only the new ones.
4. Confirm tables exist under **Table Editor**: `organizations`, `profiles`, `organization_invites`, `forms`, `questions`, `responses`, `answers`, `submission_rate_limits`, `submission_dedupe`, `feedback_processing_jobs`, `feedback_analysis`, `complaint_tasks`, `notification_events`

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

## 3b. Google One Tap and Google sign-in (optional)

Kaydo keeps Google sign-in disabled until `GOOGLE_WEB_CLIENT_ID` is present in
the frontend build. Configure it in this order:

1. In Google Cloud Console, configure the OAuth consent screen, Terms of
   Service, and Privacy Policy. Create an **OAuth 2.0 Web application** client.
2. Add `https://kaydo.sayge.in` under **Authorized JavaScript origins**. Add
   `http://localhost:3847` only for local testing. Under **Authorized redirect
   URIs**, add Supabase's OAuth callback:
   `https://wpqazaqbxuwoarouwphy.supabase.co/auth/v1/callback`. Do not add
   broad wildcards.
3. In Supabase Dashboard → Authentication → Providers → Google, enable Google
   and enter the Web Client ID and Client Secret. The secret stays in Supabase;
   it is never a Flutter or GitHub variable.
4. In Supabase Dashboard → Authentication → URL Configuration, keep
   `https://kaydo.sayge.in/**` in the redirect allow-list.
5. Add the public Web Client ID to GitHub Environment `production` as the
   variable `GOOGLE_WEB_CLIENT_ID`, and optionally to local `.env.production`.
6. Deploy the frontend, test the visible **Continue with Google** fallback,
   then test the Google-owned One Tap prompt in a clean browser profile.

One Tap is an enhancement: Google may suppress it after a dismissal or because
of browser privacy settings. Email/password and the OAuth button remain the
supported fallbacks. Do not put a Google client secret in this repository.

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

## 7b. AI Feedback-to-Action (optional but recommended)

After `20260324190000_ai_feedback_workflow.sql` is applied:

```bash
supabase functions deploy process-feedback-ai
supabase secrets set AI_ENABLED=true
supabase secrets set AI_API_KEY=sk-...
supabase secrets set AI_MODEL=gpt-4o-mini
supabase secrets set AI_WORKER_SECRET="$(openssl rand -hex 32)"
# optional OpenAI-compatible base:
# supabase secrets set AI_BASE_URL=https://api.openai.com/v1
```

- Customer submit still succeeds if AI is down (`submit-feedback` fire-and-forget).
- Jobs enqueue via DB trigger on `responses` insert.
- Org kill switch: `organizations.ai_feedback_enabled`.
- Monthly cap: `organizations.ai_monthly_analysis_limit` (default 100).
- Global kill switch: Edge secret `AI_ENABLED=false`.

Schedule a cron (Dashboard → Edge Functions → Schedules) to call
`process-feedback-ai` every 1–5 minutes as a backup worker. It must send the
same `AI_WORKER_SECRET` in the `x-ai-worker-secret` header. Do **not** put the
Supabase service-role key in a scheduler or Flutter client. The worker rejects
missing or incorrect secrets before claiming queue jobs.

**Subscription note:** `plan_id` cannot be changed by authenticated clients.
Paid entitlements stay locked until a payment webhook (service_role) is wired.

## 7c. Reviews API (Developer Docs)

After `20260324192000_reviews_api.sql` is applied:

```bash
supabase functions deploy reviews-api --no-verify-jwt
```

`--no-verify-jwt` is required so callers authenticate with `X-API-Key` instead of a user JWT.

- Only Pro orgs can create keys or call the API (server-enforced). The response
  contains only explicitly published review text and rating; raw answers never
  leave Kaydo through this API.
- Admins mark reviews **Public** in Reviews; only those appear in `GET /functions/v1/reviews-api`.
- Rate limit: 60 requests / minute / key.

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

- [ ] Migrations applied through `20261115193000_...` (no seed)
- [ ] `process-feedback-ai` deployed with `AI_API_KEY` and `AI_WORKER_SECRET` (if using AI)
- [ ] Site URL + redirects set (include reset-password)
- [ ] `.env.production` filled (never commit) including `TURNSTILE_SITE_KEY`
- [ ] App built with `DATA_SOURCE=supabase` + Turnstile site key
- [ ] `submit-feedback` deployed with `TURNSTILE_SECRET_KEY`
- [ ] Hostinger upload + SSL
- [ ] Sign-up → onboarding → publish → public submit (with captcha) smoke-tested
- [ ] Password reset + mobile invite smoke-tested
- [ ] Confirm plan change from the app is rejected (Coming soon)
- [ ] Confirm a Free and Growth API key both receive 403; Pro receives only explicit public review fields
