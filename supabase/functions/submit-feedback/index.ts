// Public feedback submit — Cloudflare Turnstile required, then RPC via service role.
// Secrets: TURNSTILE_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

// Keep the server-side acceptance boundary aligned with the only production
// public form origin. Cloudflare also enforces the widget's allowed hostnames,
// but rejecting an unexpected hostname here prevents a valid token issued for
// another origin from being used if that dashboard configuration ever drifts.
const turnstileHostname = 'kaydo.sayge.in'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
    const contentLength = Number(req.headers.get('content-length') ?? '0')
    if (Number.isFinite(contentLength) && contentLength > 80 * 1024) {
      return json({ error: 'Submission is too large' }, 413)
    }
    const rawBody = await req.text()
    if (rawBody.length > 80 * 1024) return json({ error: 'Submission is too large' }, 413)
    const body = JSON.parse(rawBody) as Record<string, unknown>
    if (!body || Array.isArray(body)) return json({ error: 'Invalid submission' }, 400)
    const formId = body.form_id as string | undefined
    const answers = body.answers ?? {}
    const metadata = body.metadata ?? {}
    const clientKey = (body.client_key as string | undefined) ?? null
    const submissionId = body.submission_id as string | undefined
    const turnstileToken = body.turnstile_token as string | undefined

    if (!formId) {
      return json({ error: 'Missing form_id' }, 400)
    }

    const secret = (Deno.env.get('TURNSTILE_SECRET_KEY') ?? '').trim()
    if (!secret) {
      return json(
        {
          error:
            'Bot protection is not configured. Set TURNSTILE_SECRET_KEY on the submit-feedback function.',
        },
        503,
      )
    }
    if (!turnstileToken || !String(turnstileToken).trim()) {
      return json({ error: 'Captcha required' }, 400)
    }

    const verify = await fetch(
      'https://challenges.cloudflare.com/turnstile/v0/siteverify',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          secret,
          response: turnstileToken,
        }),
      },
    )
    const result = await verify.json().catch(() => null)
    if (!result?.success || result.hostname !== turnstileHostname) {
      return json({ error: 'Captcha verification failed' }, 403)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, serviceKey)

    const { data, error } = await supabase.rpc('submit_public_response', {
      p_form_id: formId,
      p_answers: answers,
      p_metadata: metadata,
      p_client_key: clientKey,
      p_submission_id: submissionId ?? null,
      // Cloudflare supplies this header at the edge. It is trusted only by the
      // service-role-only RPC, never by a direct browser request.
      p_source_ip: req.headers.get('cf-connecting-ip') ??
          req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null,
    })

    if (error) {
      const code = publicErrorCode(error.message)
      const status = code === 'RATE_LIMITED' ? 429 : code === 'FORM_UNAVAILABLE' ? 404 : 400
      return json({ error: code === 'RATE_LIMITED' ? 'Too many submissions. Please try again later.' : 'Unable to submit feedback.' }, status)
    }

    // Fire-and-forget AI worker. Never fail the customer submit if AI is down.
    const workerSecret = (Deno.env.get('AI_WORKER_SECRET') ?? '').trim()
    if (workerSecret) {
      const aiUrl = `${supabaseUrl}/functions/v1/process-feedback-ai`
      fetch(aiUrl, {
        method: 'POST',
        headers: { 'x-ai-worker-secret': workerSecret, 'Content-Type': 'application/json' },
        body: JSON.stringify({ limit: 3 }),
      }).catch(() => {})
    }

    return json({ response_id: data }, 200)
  } catch (e) {
    console.error('Public submission failed', e)
    return json({ error: 'Unable to submit feedback.' }, 400)
  }
})

function publicErrorCode(message: string): string {
  for (const code of ['RATE_LIMITED', 'FORM_UNAVAILABLE', 'DUPLICATE_SUBMISSION']) {
    if (message.includes(code)) return code
  }
  return 'INVALID_SUBMISSION'
}

function json(payload: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
