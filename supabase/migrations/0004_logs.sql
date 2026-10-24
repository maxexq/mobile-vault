-- Mobile Vault: player logs in the cloud (MV-116). Run once in Supabase > SQL Editor, after 0003.
-- The game's Telemetry autoload sends Trace entries (session, error, save, economy samples, progression,
-- combat, crew, expeditions, god actions) in batches through rpc_log(). The server stamps every row with the
-- caller's user id and player id (it does not trust the client for either). Players can only insert; reading
-- is for the owner in the SQL Editor / Table Editor (postgres role).
--
-- Where to look (Supabase dashboard):
--   Table Editor > logs                          every row; filter by player_id, cat, t
--   select * from public.log_errors_recent;      last 200 errors with player id and game version
--   select * from public.log_errors_daily;       errors per day and version (+ how many players hit them)
--   select * from public.log_players_daily;      active players, sessions and rows per day
--   select * from public.log_player('0G3SQ-MSKUU');   one player's timeline, newest first (forgiving like find_player)
-- Housekeeping: delete from public.logs where t < now() - interval '90 days';

create table if not exists public.logs (
  id           bigint generated always as identity primary key,
  user_id      uuid        not null references auth.users (id) on delete cascade,
  player_id    text        not null,
  session      text        not null,
  t            timestamptz not null,
  cat          text        not null,
  msg          text        not null,
  data         jsonb,
  game_version text,
  received_at  timestamptz not null default now()
);

create index if not exists logs_player_t on public.logs (player_id, t desc);
create index if not exists logs_cat_t    on public.logs (cat, t desc);
create index if not exists logs_user_received on public.logs (user_id, received_at desc);

alter table public.logs enable row level security;
-- no policies: players never read or write the table directly, only through rpc_log below

-- One batch (at most 500 entries). Each entry: {t: unix seconds, sid, cat, msg, data}.
-- Caps: msg 500 chars, data 4 KB (bigger data is replaced by a note), 5000 rows per player per hour.
create or replace function public.rpc_log(p_events jsonb, p_version text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  n int;
  recent int;
begin
  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'not signed in');
  end if;
  if jsonb_typeof(p_events) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'events must be an array');
  end if;
  n := jsonb_array_length(p_events);
  if n = 0 then
    return jsonb_build_object('ok', true, 'n', 0);
  end if;
  if n > 500 then
    return jsonb_build_object('ok', false, 'error', 'batch too big');
  end if;
  select count(*) into recent from public.logs
    where user_id = uid and received_at > now() - interval '1 hour';
  if recent + n > 5000 then
    return jsonb_build_object('ok', false, 'error', 'rate limit');
  end if;
  insert into public.logs (user_id, player_id, session, t, cat, msg, data, game_version)
  select uid, public.player_id(uid),
         left(coalesce(e->>'sid', ''), 32),
         to_timestamp(coalesce((e->>'t')::double precision, extract(epoch from now()))),
         left(coalesce(e->>'cat', ''), 32),
         left(coalesce(e->>'msg', ''), 500),
         case when e->'data' is null then null
              when length((e->'data')::text) > 4096 then jsonb_build_object('truncated', length((e->'data')::text))
              else e->'data' end,
         left(p_version, 32)
  from jsonb_array_elements(p_events) e;
  return jsonb_build_object('ok', true, 'n', n);
end $$;

revoke all on function public.rpc_log(jsonb, text) from public, anon;
grant execute on function public.rpc_log(jsonb, text) to authenticated;

-- ---------------------------------------------------------------- dashboard views (owner only)
create or replace view public.log_errors_recent as
  select t, player_id, game_version, msg, data->>'kind' as kind, session
  from public.logs where cat = 'error'
  order by t desc limit 200;

create or replace view public.log_errors_daily as
  select date_trunc('day', t) as day, game_version, count(*) as errors, count(distinct player_id) as players
  from public.logs where cat = 'error'
  group by 1, 2 order by 1 desc, 3 desc;

create or replace view public.log_players_daily as
  select date_trunc('day', t) as day, count(distinct player_id) as players,
         count(distinct session) as sessions, count(*) as rows
  from public.logs
  group by 1 order by 1 desc;

create or replace function public.log_player(p_id text)
returns setof public.logs language sql stable security definer set search_path = '' as $$
  select * from public.logs
  where replace(player_id, '-', '') = translate(upper(regexp_replace(p_id, '[^0-9A-Za-z]', '', 'g')), 'ODIL', '0011')
  order by t desc limit 1000;
$$;

-- views run as their owner: keep them away from the anon / authenticated API roles
revoke all on public.log_errors_recent, public.log_errors_daily, public.log_players_daily from public, anon, authenticated;
revoke all on function public.log_player(text) from public, anon, authenticated;
