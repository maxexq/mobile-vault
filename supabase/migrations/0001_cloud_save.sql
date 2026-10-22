-- Mobile Vault cloud save (run once in Supabase > SQL Editor)
-- One row per player. The game writes through rpc_save() so the server
-- checks the revision (no silent overwrite between two devices) and stamps
-- the time with its own clock (offline progress can't be faked by the phone clock).

create table if not exists public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) <= 32),
  created_at   timestamptz not null default now()
);

create table if not exists public.saves (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  rev            bigint      not null default 0,
  schema_version int         not null default 1,
  game_version   text,
  device_id      text,
  data           jsonb       not null,
  settings       jsonb       not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.saves    enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own save" on public.saves;
create policy "own save" on public.saves
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Compare-and-set write. p_base_rev = the rev the client last saw (0 = none).
-- p_force = true overwrites whatever is there (player picked "use this device").
-- Returns {ok, rev, server_time} or {ok:false, conflict:true, rev, updated_at, server_time}.
create or replace function public.rpc_save(
  p_base_rev bigint, p_data jsonb, p_settings jsonb,
  p_schema int, p_game_version text, p_device_id text, p_force boolean default false
) returns jsonb
language plpgsql security invoker set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cur public.saves%rowtype;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if octet_length(p_data::text) > 2000000 then
    raise exception 'save too large' using errcode = '22023';
  end if;
  select * into cur from public.saves where user_id = uid for update;
  if not found then
    insert into public.saves (user_id, rev, schema_version, game_version, device_id, data, settings)
    values (uid, 1, p_schema, p_game_version, p_device_id, p_data, coalesce(p_settings, '{}'::jsonb));
    insert into public.profiles (user_id) values (uid) on conflict do nothing;
    return jsonb_build_object('ok', true, 'rev', 1, 'server_time', extract(epoch from now()));
  end if;
  if not p_force and cur.rev <> p_base_rev then
    return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur.rev,
      'device_id', cur.device_id, 'updated_at', extract(epoch from cur.updated_at),
      'server_time', extract(epoch from now()));
  end if;
  update public.saves set rev = cur.rev + 1, schema_version = p_schema, game_version = p_game_version,
    device_id = p_device_id, data = p_data, settings = coalesce(p_settings, settings), updated_at = now()
  where user_id = uid;
  return jsonb_build_object('ok', true, 'rev', cur.rev + 1, 'server_time', extract(epoch from now()));
end $$;

-- Read own save plus the server clock (also used just to get the time).
create or replace function public.rpc_load() returns jsonb
language sql stable security invoker set search_path = public
as $$
  select jsonb_build_object(
    'server_time', extract(epoch from now()),
    'save', (select jsonb_build_object('rev', rev, 'schema_version', schema_version,
               'game_version', game_version, 'device_id', device_id, 'data', data,
               'settings', settings, 'updated_at', extract(epoch from updated_at))
             from public.saves where user_id = auth.uid()))
$$;

revoke all on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) from public, anon;
revoke all on function public.rpc_load() from public, anon;
grant execute on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) to authenticated;
grant execute on function public.rpc_load() to authenticated;
