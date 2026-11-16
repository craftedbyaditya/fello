-- Board is not part of the Free public launch. Existing task data remains
-- readable to authorized users, but no task/comment mutation can bypass the
-- global release switch through PostgREST or an older client build.
create or replace function public.enforce_task_board_feature_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_feature_enabled('task_board_enabled') then
    raise exception 'FEATURE_DISABLED: task board is unavailable';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_enforce_task_board_feature_flag_tasks on public.complaint_tasks;
create trigger trg_enforce_task_board_feature_flag_tasks
  before insert or update or delete on public.complaint_tasks
  for each row execute function public.enforce_task_board_feature_flag();

drop trigger if exists trg_enforce_task_board_feature_flag_comments on public.task_comments;
create trigger trg_enforce_task_board_feature_flag_comments
  before insert or update or delete on public.task_comments
  for each row execute function public.enforce_task_board_feature_flag();

revoke all on function public.enforce_task_board_feature_flag() from public, anon, authenticated;
