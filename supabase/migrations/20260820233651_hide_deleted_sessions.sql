-- Keep soft-deleted sessions out of all shared history queries.
drop policy if exists workout_sessions_select_owner_or_friend
  on public.workout_sessions;
create policy workout_sessions_select_owner_or_friend
  on public.workout_sessions for select to authenticated
  using (
    deleted_at is null
    and (
      owner_id = (select auth.uid())
      or exists (
        select 1
        from public.friendships f
        where f.status = 'accepted'
          and ((f.requester_id = (select auth.uid()) and f.addressee_id = owner_id)
            or (f.addressee_id = (select auth.uid()) and f.requester_id = owner_id))
      )
    )
  );
