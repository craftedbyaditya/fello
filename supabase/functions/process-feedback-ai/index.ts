// Processes feedback_processing_jobs: AI analysis → optional complaint task + notification.
// Secrets: AI_ENABLED, AI_API_KEY, AI_MODEL, AI_BASE_URL (optional),
//          SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Content-Type': 'application/json',
}

type AiResult = {
  sentiment: 'positive' | 'neutral' | 'mixed' | 'negative'
  primary_category: string
  categories: string[]
  positive_aspects: string[]
  urgency: 'low' | 'medium' | 'high' | 'critical'
  summary: string
  action_recommended: boolean
  confidence: number
}

Deno.serve(async (req) => {
  // This is a queue worker, not a browser API. A scheduler must set the same
  // secret configured as AI_WORKER_SECRET. Service-role credentials are never
  // accepted from a caller and are only read inside the function runtime.
  if (req.method !== 'POST' || !isTrustedWorkerRequest(req)) {
    return json({ error: 'Unauthorized' }, 401)
  }

  try {
    const globalOn = (Deno.env.get('AI_ENABLED') ?? 'true').trim().toLowerCase()
    if (globalOn === 'false' || globalOn === '0' || globalOn === 'off') {
      return json({ processed: 0, skipped: 'AI_ENABLED=false' }, 200)
    }

    const apiKey = (Deno.env.get('AI_API_KEY') ?? '').trim()
    if (!apiKey) {
      return json(
        { error: 'AI_API_KEY is not configured', processed: 0 },
        503,
      )
    }

    const model = (Deno.env.get('AI_MODEL') ?? 'gpt-4o-mini').trim()
    const baseUrl = (
      Deno.env.get('AI_BASE_URL') ?? 'https://api.openai.com/v1'
    ).replace(/\/$/, '')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const body = await req.json().catch(() => ({}))
    const requestedLimit = typeof body.limit === 'number' ? body.limit : 5
    const limit = Math.max(1, Math.min(20, Math.floor(requestedLimit)))

    const { data: jobs, error: claimErr } = await supabase.rpc(
      'claim_feedback_ai_jobs',
      { p_limit: limit },
    )
    if (claimErr) {
      console.error('Unable to claim AI jobs', claimErr)
      return json({ error: 'Unable to process queued work' }, 500)
    }
    if (!jobs || jobs.length === 0) {
      return json({ processed: 0 }, 200)
    }

    const results: Array<Record<string, unknown>> = []
    for (const job of jobs as Array<Record<string, unknown>>) {
      const outcome = await processJob(supabase, job, {
        apiKey,
        model,
        baseUrl,
      })
      results.push(outcome)
    }

    return json({ processed: results.length, results }, 200)
  } catch (e) {
    console.error('AI worker failed', e)
    return json({ error: 'Unable to process queued work' }, 500)
  }
})

function isTrustedWorkerRequest(req: Request): boolean {
  const configured = (Deno.env.get('AI_WORKER_SECRET') ?? '').trim()
  if (!configured) {
    // Fail closed: deploying without the scheduler secret must not expose the
    // global queue to authenticated users.
    console.error('AI_WORKER_SECRET is not configured')
    return false
  }
  const supplied = (req.headers.get('x-ai-worker-secret') ?? '').trim()
  return constantTimeEqual(supplied, configured)
}

function constantTimeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left)
  const b = new TextEncoder().encode(right)
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}

async function processJob(
  supabase: ReturnType<typeof createClient>,
  job: Record<string, unknown>,
  cfg: { apiKey: string; model: string; baseUrl: string },
): Promise<Record<string, unknown>> {
  const jobId = job.id as string
  const orgId = job.org_id as string
  const responseId = job.response_id as string

  try {
    // Idempotent: already analyzed — still ensure complaint task exists for Board.
    const { data: existing } = await supabase
      .from('feedback_analysis')
      .select(
        'id, action_recommended, primary_category, summary, urgency, sentiment',
      )
      .eq('response_id', responseId)
      .maybeSingle()
    if (existing?.id) {
      let taskId: string | null = null
      if (existing.action_recommended === true) {
        const payload = await loadMinimizedFeedback(supabase, responseId)
        taskId = await ensureComplaintTask(supabase, {
          orgId,
          responseId,
          analysisId: existing.id as string,
          validated: {
            sentiment: (existing.sentiment as AiResult['sentiment']) ?? 'mixed',
            primary_category:
              (existing.primary_category as string) ?? 'General',
            categories: [(existing.primary_category as string) ?? 'General'],
            positive_aspects: [],
            urgency: (existing.urgency as AiResult['urgency']) ?? 'medium',
            summary: (existing.summary as string) ?? '',
            action_recommended: true,
            confidence: 1,
          },
          feedbackText: payload?.text ?? '',
        })
      }
      await markJob(supabase, jobId, 'done')
      return {
        job_id: jobId,
        status: 'done',
        reason: 'already_analyzed',
        task_id: taskId,
      }
    }

    const { data: org } = await supabase
      .from('organizations')
      .select('ai_feedback_enabled, ai_monthly_analysis_limit, business_type')
      .eq('id', orgId)
      .single()

    if (org && org.ai_feedback_enabled === false) {
      await markJob(supabase, jobId, 'skipped', 'org_ai_disabled')
      return { job_id: jobId, status: 'skipped', reason: 'org_ai_disabled' }
    }

    const { data: quotaAllowed, error: quotaError } = await supabase.rpc(
      'consume_ai_analysis_quota',
      { p_org_id: orgId },
    )
    if (quotaError) throw quotaError
    if (quotaAllowed !== true) {
      await markJob(supabase, jobId, 'skipped', 'monthly_limit')
      return { job_id: jobId, status: 'skipped', reason: 'monthly_limit' }
    }

    const payload = await loadMinimizedFeedback(supabase, responseId)
    if (!payload) {
      await markJob(supabase, jobId, 'failed', 'response_not_found')
      return { job_id: jobId, status: 'failed', reason: 'response_not_found' }
    }

    if (!shouldAnalyze(payload)) {
      await markJob(supabase, jobId, 'skipped', 'not_eligible')
      return { job_id: jobId, status: 'skipped', reason: 'not_eligible' }
    }

    const ai = await callAi(cfg, payload, org?.business_type as string | null)
    const validated = validateAi(ai)
    if (!validated) {
      await markJob(supabase, jobId, 'failed', 'invalid_ai_output')
      return { job_id: jobId, status: 'failed', reason: 'invalid_ai_output' }
    }

    const { data: analysis, error: aErr } = await supabase
      .from('feedback_analysis')
      .insert({
        org_id: orgId,
        response_id: responseId,
        sentiment: validated.sentiment,
        primary_category: validated.primary_category,
        categories: validated.categories,
        positive_aspects: validated.positive_aspects,
        urgency: validated.urgency,
        summary: validated.summary,
        action_recommended: validated.action_recommended,
        confidence: validated.confidence,
        model: cfg.model,
      })
      .select('id')
      .single()

    if (aErr) {
      // Unique race → ensure task then done (same as already_analyzed path)
      if (aErr.code === '23505') {
        const { data: raced } = await supabase
          .from('feedback_analysis')
          .select(
            'id, action_recommended, primary_category, summary, urgency, sentiment',
          )
          .eq('response_id', responseId)
          .maybeSingle()
        let taskId: string | null = null
        if (raced?.action_recommended === true) {
          taskId = await ensureComplaintTask(supabase, {
            orgId,
            responseId,
            analysisId: raced.id as string,
            validated: {
              sentiment: (raced.sentiment as AiResult['sentiment']) ?? 'mixed',
              primary_category:
                (raced.primary_category as string) ?? 'General',
              categories: [(raced.primary_category as string) ?? 'General'],
              positive_aspects: [],
              urgency: (raced.urgency as AiResult['urgency']) ?? 'medium',
              summary: (raced.summary as string) ?? '',
              action_recommended: true,
              confidence: 1,
            },
            feedbackText: payload.text,
          })
        }
        await markJob(supabase, jobId, 'done')
        return {
          job_id: jobId,
          status: 'done',
          reason: 'race_duplicate',
          task_id: taskId,
        }
      }
      throw aErr
    }

    let taskId: string | null = null
    if (validated.action_recommended) {
      taskId = await ensureComplaintTask(supabase, {
        orgId,
        responseId,
        analysisId: analysis.id as string,
        validated,
        feedbackText: payload.text,
      })
    }

    await markJob(supabase, jobId, 'done')
    return {
      job_id: jobId,
      status: 'done',
      analysis_id: analysis.id,
      task_id: taskId,
    }
  } catch (e) {
    const msg = `${e}`.slice(0, 500)
    await markJob(supabase, jobId, 'failed', msg)
    return { job_id: jobId, status: 'failed', error: msg }
  }
}

async function loadMinimizedFeedback(
  supabase: ReturnType<typeof createClient>,
  responseId: string,
): Promise<{ text: string; rating: number | null; businessType: string | null } | null> {
  const { data: response } = await supabase
    .from('responses')
    .select('id, form_id, forms!inner(org_id, organizations(business_type))')
    .eq('id', responseId)
    .maybeSingle()
  if (!response) return null

  const { data: answers } = await supabase
    .from('answers')
    .select('value, questions!inner(type, label)')
    .eq('response_id', responseId)

  let rating: number | null = null
  const texts: string[] = []
  for (const row of answers ?? []) {
    const q = row.questions as { type?: string; label?: string } | null
    const type = q?.type ?? ''
    const value = row.value
    if (type === 'starRating' && typeof value === 'number') {
      rating = value
    } else if (type === 'nps' && typeof value === 'number' && rating == null) {
      rating = Math.max(1, Math.round(value / 2))
    } else if (
      (type === 'shortText' || type === 'longText') &&
      typeof value === 'string' &&
      value.trim()
    ) {
      texts.push(value.trim().slice(0, 500))
    }
  }

  const forms = response.forms as {
    organizations?: { business_type?: string | null }
  } | null

  return {
    text: texts.join(' ').slice(0, 800),
    rating,
    businessType: forms?.organizations?.business_type ?? null,
  }
}

function shouldAnalyze(payload: {
  text: string
  rating: number | null
}): boolean {
  const hasText = payload.text.trim().length >= 8
  const lowRating = payload.rating != null && payload.rating <= 3
  return hasText || lowRating
}

async function callAi(
  cfg: { apiKey: string; model: string; baseUrl: string },
  payload: { text: string; rating: number | null; businessType: string | null },
  businessType: string | null,
): Promise<unknown> {
  const industry = businessType || payload.businessType || 'general service'
  const system = `You analyze customer feedback for a ${industry} business in India.
Return ONLY valid JSON with keys:
sentiment (positive|neutral|mixed|negative),
primary_category (short string),
categories (string array),
positive_aspects (string array),
urgency (low|medium|high|critical),
summary (max 140 chars),
action_recommended (boolean),
confidence (0-1 number).
Use practical categories like Waiting Time, Staff, Cleanliness, Quality, Pricing, Communication, Facilities, Safety, Other.
Recommend action when sentiment is negative/mixed or urgency is high/critical.`

  const user = JSON.stringify({
    rating_out_of_5: payload.rating,
    feedback_text: payload.text || '(no text)',
  })

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 25000)
  try {
    const res = await fetch(`${cfg.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: cfg.model,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      }),
      signal: controller.signal,
    })
    if (!res.ok) {
      const errText = await res.text()
      throw new Error(`AI HTTP ${res.status}: ${errText.slice(0, 200)}`)
    }
    const data = await res.json()
    const content = data?.choices?.[0]?.message?.content
    if (!content || typeof content !== 'string') {
      throw new Error('AI empty content')
    }
    return JSON.parse(content)
  } finally {
    clearTimeout(timer)
  }
}

function validateAi(raw: unknown): AiResult | null {
  if (!raw || typeof raw !== 'object') return null
  const o = raw as Record<string, unknown>
  const sentiments = ['positive', 'neutral', 'mixed', 'negative']
  const urgencies = ['low', 'medium', 'high', 'critical']
  const sentiment = String(o.sentiment ?? '')
  const urgency = String(o.urgency ?? 'low')
  if (!sentiments.includes(sentiment)) return null
  if (!urgencies.includes(urgency)) return null

  const primary = String(o.primary_category ?? 'General').trim().slice(0, 64) ||
    'General'
  const categories = Array.isArray(o.categories)
    ? o.categories.map((c) => String(c).trim().slice(0, 64)).filter(Boolean).slice(0, 6)
    : [primary]
  const positives = Array.isArray(o.positive_aspects)
    ? o.positive_aspects.map((c) => String(c).trim().slice(0, 80)).filter(Boolean).slice(0, 6)
    : []
  const summary = String(o.summary ?? '').trim().slice(0, 200)
  const confidence = Number(o.confidence)
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) return null

  return {
    sentiment: sentiment as AiResult['sentiment'],
    primary_category: primary,
    categories: categories.length ? categories : [primary],
    positive_aspects: positives,
    urgency: urgency as AiResult['urgency'],
    summary: summary || 'Feedback reviewed.',
    action_recommended: Boolean(o.action_recommended),
    confidence,
  }
}

async function ensureComplaintTask(
  supabase: ReturnType<typeof createClient>,
  args: {
    orgId: string
    responseId: string
    analysisId: string
    validated: AiResult
    feedbackText: string
  },
): Promise<string | null> {
  const { data: existing } = await supabase
    .from('complaint_tasks')
    .select('id')
    .eq('response_id', args.responseId)
    .maybeSingle()
  if (existing?.id) return existing.id as string

  const { data: admin } = await supabase
    .from('profiles')
    .select('id')
    .eq('org_id', args.orgId)
    .eq('role', 'admin')
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  const { data: responseRow } = await supabase
    .from('responses')
    .select('form_id')
    .eq('id', args.responseId)
    .maybeSingle()
  const formId = (responseRow?.form_id as string | undefined) ?? null

  const title = `${args.validated.primary_category}: follow up`
  const description =
    `${args.validated.summary}\n\nCustomer: ${args.feedbackText || '(rating only)'}`.slice(
      0,
      2000,
    )

  const { data: task, error } = await supabase
    .from('complaint_tasks')
    .insert({
      org_id: args.orgId,
      response_id: args.responseId,
      analysis_id: args.analysisId,
      title,
      description,
      category: args.validated.primary_category,
      priority: args.validated.urgency,
      status: 'open',
      assigned_to: admin?.id ?? null,
      created_by: null,
      source: 'ai',
      due_at: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    })
    .select('id, assigned_to')
    .single()

  if (error) {
    if (error.code === '23505') {
      const { data: again } = await supabase
        .from('complaint_tasks')
        .select('id')
        .eq('response_id', args.responseId)
        .maybeSingle()
      return (again?.id as string) ?? null
    }
    throw error
  }

  const notifyUser = (task.assigned_to as string | null) ?? admin?.id
  if (notifyUser) {
    await supabase.from('notification_events').insert({
      org_id: args.orgId,
      user_id: notifyUser,
      type: 'complaint_task',
      title: 'New survey follow-up',
      body: title,
      payload: {
        task_id: task.id,
        response_id: args.responseId,
        form_id: formId,
        category: args.validated.primary_category,
      },
    })
  }

  return task.id as string
}

async function markJob(
  supabase: ReturnType<typeof createClient>,
  jobId: string,
  status: string,
  error?: string,
) {
  await supabase
    .from('feedback_processing_jobs')
    .update({
      status,
      last_error: error ?? null,
      skip_reason: status === 'skipped' ? error ?? null : null,
      updated_at: new Date().toISOString(),
      processed_at: ['done', 'skipped'].includes(status)
        ? new Date().toISOString()
        : null,
    })
    .eq('id', jobId)
}

function json(payload: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
