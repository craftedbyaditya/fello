// Public Reviews API — authenticate with X-API-Key (Pro only).
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-api-key',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

const DEFAULT_LIMIT = 20
const MAX_LIMIT = 100
const RATE_PER_MINUTE = 60

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'GET') {
    return json({ error: 'Method not allowed' }, 405)
  }

  try {
    const url = new URL(req.url)
    const path = url.pathname.replace(/\/+$/, '')
    // Accept /reviews-api or /reviews-api/reviews
    if (!path.endsWith('reviews-api') && !path.endsWith('/reviews')) {
      return json({ error: 'Not found' }, 404)
    }

    const apiKey = (
      req.headers.get('x-api-key') ??
      req.headers.get('X-API-Key') ??
      ''
    ).trim()
    if (!apiKey) {
      return json({ error: 'Missing or invalid API key' }, 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: resolved, error: resolveErr } = await supabase.rpc(
      'resolve_org_api_key',
      { p_api_key: apiKey },
    )
    if (resolveErr) {
      return json({ error: 'Internal server error' }, 500)
    }
    const row = Array.isArray(resolved) ? resolved[0] : resolved
    if (!row?.org_id) {
      return json({ error: 'Missing or invalid API key' }, 401)
    }
    if (row.revoked === true) {
      return json({ error: 'Missing or invalid API key' }, 401)
    }
    if ((row.plan_id as string) !== 'pro') {
      return json(
        { error: 'Pro plan required for Reviews API access' },
        403,
      )
    }

    const { data: allowed, error: rateErr } = await supabase.rpc(
      'consume_api_key_rate',
      { p_key_id: row.key_id, p_limit: RATE_PER_MINUTE },
    )
    if (rateErr) {
      return json({ error: 'Internal server error' }, 500)
    }
    if (allowed === false) {
      return json({ error: 'Rate limit exceeded' }, 429)
    }

    const limitRaw = Number(url.searchParams.get('limit') ?? DEFAULT_LIMIT)
    const limit = Number.isFinite(limitRaw)
      ? Math.min(MAX_LIMIT, Math.max(1, Math.floor(limitRaw)))
      : DEFAULT_LIMIT
    const cursor = url.searchParams.get('cursor')

    let query = supabase
      .from('responses')
      .select(
        `
        id,
        submitted_at,
        form_id,
        forms!inner(org_id, title, slug),
        public_review_text,
        public_review_rating,
        public_review_published_at
      `,
      )
      .eq('forms.org_id', row.org_id)
      .eq('is_public', true)
      .not('public_review_text', 'is', null)
      .order('submitted_at', { ascending: false })
      .order('id', { ascending: false })
      .limit(limit + 1)

    if (cursor) {
      const decoded = decodeCursor(cursor)
      if (!decoded) {
        return json({ error: 'Invalid cursor' }, 400)
      }
      query = query.or(
        `submitted_at.lt.${decoded.submittedAt},and(submitted_at.eq.${decoded.submittedAt},id.lt.${decoded.id})`,
      )
    }

    const { data: rows, error: listErr } = await query
    if (listErr) {
      return json({ error: 'Internal server error' }, 500)
    }

    const list = rows ?? []
    const hasMore = list.length > limit
    const page = hasMore ? list.slice(0, limit) : list
    const last = page.length ? page[page.length - 1] : null
    const nextCursor = hasMore && last
      ? encodeCursor(last.submitted_at as string, last.id as string)
      : null

    const reviews = page.map(mapReview)

    return json(
      {
        data: reviews,
        pagination: {
          limit,
          next_cursor: nextCursor,
          has_more: hasMore,
        },
      },
      200,
    )
  } catch (e) {
    console.error(e)
    return json({ error: 'Internal server error' }, 500)
  }
})

function mapReview(row: Record<string, unknown>) {
  const forms = row.forms as { title?: string; slug?: string } | null
  // Explicit publication fields only. Never infer public data from answers:
  // answers may contain email, phone, staff notes, or other PII.
  return {
    id: row.id,
    form_id: row.form_id,
    form_title: forms?.title ?? null,
    form_slug: forms?.slug ?? null,
    published_at: row.public_review_published_at,
    rating: row.public_review_rating ?? null,
    comment: row.public_review_text,
  }
}

function encodeCursor(submittedAt: string, id: string): string {
  return btoa(JSON.stringify({ submitted_at: submittedAt, id }))
}

function decodeCursor(
  cursor: string,
): { submittedAt: string; id: string } | null {
  try {
    const raw = JSON.parse(atob(cursor))
    if (
      typeof raw?.submitted_at === 'string' &&
      typeof raw?.id === 'string'
    ) {
      return { submittedAt: raw.submitted_at, id: raw.id }
    }
  } catch (_) {
    /* ignore */
  }
  return null
}

function json(payload: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
