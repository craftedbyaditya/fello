-- Allow a user to read their own profile by auth.uid().
-- Fixes signup/sign-in hanging when org-scoped profile SELECT raced the
-- handle_new_user trigger / current_org_id() lookup.

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid());
