drop policy if exists profiles_select_self_or_friend on public.profiles;

create policy profiles_select_self_friend_or_pending
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1
      from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = (select auth.uid()) and f.addressee_id = id)
          or (f.addressee_id = (select auth.uid()) and f.requester_id = id))
    )
    or exists (
      select 1
      from public.friend_requests r
      where r.status = 'pending'
        and ((r.requester_id = (select auth.uid()) and r.target_id = id)
          or (r.target_id = (select auth.uid()) and r.requester_id = id))
    )
  );
