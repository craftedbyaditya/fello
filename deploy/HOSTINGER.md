# Publish Kaydo on Hostinger (`kaydo.sayge.in`)

Kaydo is a **static Flutter web** app. On Hostinger you host the contents of `build/web` on a subdomain and keep SPA rewrites so routes like `/f/my-form` work.

## 1. Build locally

```bash
cp .env.production.example .env.production
# fill SUPABASE_URL + SUPABASE_ANON_KEY

set -a && source .env.production && set +a
./scripts/build_web.sh
```

Upload **everything inside** `build/web/` (including `.htaccess`, `index.html`, `assets/`, `canvaskit/`, etc.).

`PUBLIC_BASE_URL` must be `https://kaydo.sayge.in` so QR/share links are correct.

Complete **`deploy/SUPABASE_SETUP.md` first** (migrations + keys). Do **not** run `seed.sql` in production.

## 2. Create the subdomain in Hostinger

1. Log in to **hPanel**.
2. Open **Domains** → **Subdomains** (or Domains → manage `sayge.in` → Subdomains).
3. Create subdomain: **`kaydo`** → full host `kaydo.sayge.in`.
4. Note the document root Hostinger assigns (often something like):
   - `public_html/kaydo`
   - or `domains/kaydo.sayge.in/public_html`

## 3. DNS

If `sayge.in` DNS is already on Hostinger, the subdomain usually appears automatically.

If DNS is elsewhere (Cloudflare, etc.):

| Type | Name | Points to |
|------|------|-----------|
| **A** | `kaydo` | Hostinger hosting IP (from hPanel → Domains / DNS) |
| or **CNAME** | `kaydo` | Hostinger target they show for the subdomain |

Wait for DNS to propagate (often minutes, sometimes up to a few hours).

## 4. Upload the site

### Option A — File Manager (simplest)

1. hPanel → **Files** → **File Manager**.
2. Open the subdomain folder (`public_html/kaydo` or the path from step 2).
3. Delete any default `index.html` / placeholder files.
4. Upload **all files from** `build/web/` into that folder root (not nested in another `web` folder).
5. Confirm these exist at the root:
   - `index.html`
   - `.htaccess` (SPA rewrite — required)
   - `flutter_bootstrap.js` / `main.dart.js`
   - `assets/`

### Option B — FTP / SFTP

1. hPanel → **Files** → **FTP Accounts** (create one if needed).
2. Connect with FileZilla (or similar).
3. Upload `build/web/*` into the subdomain document root.

## 5. SSL (HTTPS)

1. hPanel → **SSL** / **SSL Certificates**.
2. Enable **free SSL** for `kaydo.sayge.in`.
3. Turn on **Force HTTPS** if available.
4. Visit `https://kaydo.sayge.in` — padlock should show.

## 6. Supabase (required for real data)

In Supabase → **Authentication** → **URL configuration**:

- **Site URL:** `https://kaydo.sayge.in`
- **Redirect URLs:** `https://kaydo.sayge.in/**`

Without this, sign-in / redirects can fail in production.

## 7. Smoke test

- `https://kaydo.sayge.in/sign-in`
- Soft refresh on `/dashboard` (must not 404) — proves `.htaccess` works
- Publish a form → open `https://kaydo.sayge.in/f/<slug>`
- QR / share link uses `kaydo.sayge.in`

## Redeploy later

Rebuild with `./scripts/build_web.sh`, then overwrite the same Hostinger folder with the new `build/web` files. Keep `.htaccess` (it ships from `web/.htaccess`).

## If routes 404 on refresh

Apache rewrite is off or `.htaccess` missing. Re-upload `.htaccess` and ask Hostinger support to confirm **mod_rewrite** is enabled (it usually is on shared hosting).

## VPS on Hostinger instead of shared hosting

Use the nginx sample: `deploy/nginx.kaydo.sayge.in.conf`, point the vhost root at your deployed `build/web`, then Certbot for TLS.
