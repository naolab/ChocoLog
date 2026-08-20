create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  public_id text not null unique
    check (public_id ~ '^CL-[A-Z0-9]{6}$'),
  display_name text not null default 'chocoLOG user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz,
  check (requester_id <> target_id)
);

create unique index friend_requests_pending_pair_idx
  on public.friend_requests (
    least(requester_id, target_id),
    greatest(requester_id, target_id)
  )
  where status = 'pending';

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'accepted'
    check (status in ('accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);

create unique index friendships_pair_idx
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  );

create table public.workout_sessions (
  id text primary key,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  studio_id text,
  status text not null default 'completed'
    check (status in ('draft', 'completed')),
  started_at timestamptz not null,
  ended_at timestamptz,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index workout_sessions_owner_date_idx
  on public.workout_sessions (owner_id, started_at desc);

create table public.exercise_records (
  id text primary key,
  workout_session_id text not null references public.workout_sessions (id) on delete cascade,
  equipment_id text not null,
  record_type text not null,
  started_at timestamptz,
  paused_at timestamptz,
  ended_at timestamptz,
  accumulated_paused_seconds integer not null default 0,
  timer_status text not null default 'notStarted',
  duration_seconds integer,
  distance_km double precision,
  speed_kph double precision,
  incline double precision,
  resistance integer,
  note text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index exercise_records_session_idx
  on public.exercise_records (workout_session_id, sort_order);

create table public.exercise_sets (
  id text primary key,
  exercise_record_id text not null references public.exercise_records (id) on delete cascade,
  set_number integer not null check (set_number > 0),
  weight_kg integer check (weight_kg is null or (weight_kg >= 0 and weight_kg % 5 = 0)),
  reps integer not null check (reps > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_record_id, set_number)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, public_id, display_name)
  values (
    new.id,
    'CL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      'chocoLOG user'
    )
  );
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.find_profile_by_public_id(p_public_id text)
returns table (user_id uuid, public_id text, display_name text)
language sql
security definer
set search_path = public
as $$
  select p.id, p.public_id, p.display_name
  from public.profiles p
  where auth.uid() is not null
    and p.public_id = upper(trim(p_public_id));
$$;

revoke all on function public.find_profile_by_public_id(text) from public, anon;
grant execute on function public.find_profile_by_public_id(text) to authenticated;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requester_id uuid;
begin
  select requester_id
    into v_requester_id
    from public.friend_requests
   where id = p_request_id
     and target_id = auth.uid()
     and status = 'pending'
     and (expires_at is null or expires_at > now())
   for update;

  if v_requester_id is null then
    raise exception 'friend request is not available';
  end if;

  insert into public.friendships (requester_id, addressee_id)
  values (v_requester_id, auth.uid())
  on conflict do nothing;

  update public.friend_requests
     set status = 'accepted', updated_at = now()
   where id = p_request_id;
end;
$$;

revoke all on function public.accept_friend_request(uuid) from public, anon;
grant execute on function public.accept_friend_request(uuid) to authenticated;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();
create trigger friend_requests_set_updated_at
  before update on public.friend_requests
  for each row execute procedure public.set_updated_at();
create trigger friendships_set_updated_at
  before update on public.friendships
  for each row execute procedure public.set_updated_at();
create trigger workout_sessions_set_updated_at
  before update on public.workout_sessions
  for each row execute procedure public.set_updated_at();
create trigger exercise_records_set_updated_at
  before update on public.exercise_records
  for each row execute procedure public.set_updated_at();
create trigger exercise_sets_set_updated_at
  before update on public.exercise_sets
  for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.exercise_records enable row level security;
alter table public.exercise_sets enable row level security;

create policy profiles_select_self_or_friend
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
  );

create policy profiles_update_self
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy friend_requests_select_participant
  on public.friend_requests for select to authenticated
  using (requester_id = (select auth.uid()) or target_id = (select auth.uid()));

create policy friend_requests_insert_requester
  on public.friend_requests for insert to authenticated
  with check (requester_id = (select auth.uid()) and requester_id <> target_id);

create policy friend_requests_reject_target
  on public.friend_requests for update to authenticated
  using (target_id = (select auth.uid()) and status = 'pending')
  with check (target_id = (select auth.uid()) and status = 'rejected');

create policy friend_requests_cancel_requester
  on public.friend_requests for update to authenticated
  using (requester_id = (select auth.uid()) and status = 'pending')
  with check (requester_id = (select auth.uid()) and status = 'cancelled');

create policy friendships_select_participant
  on public.friendships for select to authenticated
  using (requester_id = (select auth.uid()) or addressee_id = (select auth.uid()));

create policy friendships_delete_participant
  on public.friendships for delete to authenticated
  using (requester_id = (select auth.uid()) or addressee_id = (select auth.uid()));

create policy workout_sessions_select_owner_or_friend
  on public.workout_sessions for select to authenticated
  using (
    owner_id = (select auth.uid())
    or exists (
      select 1
      from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = (select auth.uid()) and f.addressee_id = owner_id)
          or (f.addressee_id = (select auth.uid()) and f.requester_id = owner_id))
    )
  );

create policy workout_sessions_insert_owner
  on public.workout_sessions for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy workout_sessions_update_owner
  on public.workout_sessions for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy workout_sessions_delete_owner
  on public.workout_sessions for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy exercise_records_select_owner_or_friend
  on public.exercise_records for select to authenticated
  using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_session_id
    )
  );

create policy exercise_records_insert_owner
  on public.exercise_records for insert to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_session_id and s.owner_id = (select auth.uid())
    )
  );

create policy exercise_records_update_owner
  on public.exercise_records for update to authenticated
  using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_session_id and s.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_session_id and s.owner_id = (select auth.uid())
    )
  );

create policy exercise_records_delete_owner
  on public.exercise_records for delete to authenticated
  using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_session_id and s.owner_id = (select auth.uid())
    )
  );

create policy exercise_sets_select_owner_or_friend
  on public.exercise_sets for select to authenticated
  using (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id
    )
  );

create policy exercise_sets_insert_owner
  on public.exercise_sets for insert to authenticated
  with check (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id and s.owner_id = (select auth.uid())
    )
  );

create policy exercise_sets_update_owner
  on public.exercise_sets for update to authenticated
  using (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id and s.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id and s.owner_id = (select auth.uid())
    )
  );

create policy exercise_sets_delete_owner
  on public.exercise_sets for delete to authenticated
  using (
    exists (
      select 1
      from public.exercise_records r
      join public.workout_sessions s on s.id = r.workout_session_id
      where r.id = exercise_record_id and s.owner_id = (select auth.uid())
    )
  );
