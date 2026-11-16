-- Read-only P0.9 production verification queries. Run each inside a
-- read-only transaction after the approved release package commits.

select p.oid::regprocedure as function, p.proacl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'submit_public_response'
order by 1;

select relname as table_name, relrowsecurity as rls_enabled
from pg_class
where oid in (
  'public.responses'::regclass,
  'public.org_monthly_usage'::regclass,
  'public.subscriptions'::regclass,
  'public.global_feature_flags'::regclass
)
order by relname;

select key, enabled
from public.global_feature_flags
order by key;

select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.organizations'::regclass
  and conname = 'organizations_plan_id_check';

select count(*) as legacy_custom_orgs_pending_review
from public.subscription_migration_reviews
where reviewed_at is null;

select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'org_monthly_usage'
order by ordinal_position;
