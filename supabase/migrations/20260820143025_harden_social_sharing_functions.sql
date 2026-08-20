-- Keep trigger execution independent from the caller's search_path.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- This function is only called by table triggers, never directly by clients.
revoke all on function public.set_updated_at() from public, anon, authenticated;

-- Soft-deleted sessions must not remain visible through child-table queries.
drop policy if exists exercise_records_select_owner_or_friend
  on public.exercise_records;
create policy exercise_records_select_owner_or_friend
  on public.exercise_records for select to authenticated
  using (
    exists (
      select 1
      from public.workout_sessions s
      where s.id = workout_session_id
        and s.deleted_at is null
    )
  );

drop policy if exists exercise_sets_select_owner_or_friend
  on public.exercise_sets;
create policy exercise_sets_select_owner_or_friend
  on public.exercise_sets for select to authenticated
  using (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id
        and s.deleted_at is null
    )
  );

-- Foreign-key indexes keep friend and friendship lookups bounded as the graph grows.
create index if not exists friend_requests_requester_idx
  on public.friend_requests (requester_id, created_at desc);
create index if not exists friend_requests_target_idx
  on public.friend_requests (target_id, created_at desc);
create index if not exists friendships_requester_idx
  on public.friendships (requester_id);
create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id);

-- Combine the two update policies so Postgres evaluates one permissive policy.
drop policy if exists friend_requests_reject_target
  on public.friend_requests;
drop policy if exists friend_requests_cancel_requester
  on public.friend_requests;
create policy friend_requests_update_participant
  on public.friend_requests for update to authenticated
  using (
    status = 'pending'
    and (
      target_id = (select auth.uid())
      or requester_id = (select auth.uid())
    )
  )
  with check (
    (target_id = (select auth.uid()) and status = 'rejected')
    or (requester_id = (select auth.uid()) and status = 'cancelled')
  );
