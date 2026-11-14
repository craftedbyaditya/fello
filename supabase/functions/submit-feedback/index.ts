// Public feedback submit — Cloudflare Turnstile required, then RPC via service role.
// Secrets: TURNSTILE_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const formId = body.form_id as string | undefined
    const answers = body.answers ?? {}
    const metadata = body.metadata ?? {}
    const clientKey = (body.client_key as string | undefined) ?? 'anonymous'
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
    const result = await verify.json()
    if (!result.success) {
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
    })

    if (error) {
      return json({ error: error.message }, 400)
    }

    return json({ response_id: data }, 200)
  } catch (e) {
    return json({ error: `${e}` }, 500)
  }
})

function json(payload: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
