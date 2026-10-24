-- Mobile Vault: anti-cheat F0 + F1 (MV-174, design: https://claude.ai/artifact/QWiRy6Qd5hLx5MDq8DCAP5).
-- Run once in Supabase > SQL Editor, after 0005. Safe to run again (it replaces the functions and upserts the limits).
--
-- The game keeps owning the save (local-first). This file adds what the server can check without running the game:
--   F0  * rpc_load / rpc_save keep returning the server time of the last accepted save (saves.updated_at). The game
--         caps its offline catch-up with it (Game.offline_elapsed), so moving saved_at back in local storage no
--         longer buys up to 4 free hours on every reload.
--       * a write that comes less than 3 seconds after the last accepted one is refused with
--         {ok:false, rate_limited:true}; the game keeps it queued and sends it with the next upload round.
--       * sticky flags in player_state: once a save says GOD MODE was used (stats.cheated / life.cheated) god_at is
--         set and the player can't clear it by editing the save. Tester-tool lines in the logs set god_log_at.
--   F1  * after every accepted write the server compares a few counters that only grow (simulated seconds, km,
--         kills, generations) with the previous save and the real time in between. A jump bigger than
--         anticheat_limits allows adds 1 to suspect_score and a reason, and writes an 'anticheat' row to logs.
--         The save is never refused for this: it is a shadow flag for leaderboards later, so a false positive
--         costs a real player nothing.
--
-- Players can't read or write player_state or anticheat_limits (RLS on, no policies); everything goes through the
-- security definer functions below.
--
-- Where to look:
--   select * from public.anticheat_suspects;                   flagged players, newest first
--   select * from public.player_state where user_id = (select user_id from public.find_player('0G3SQ-MSKUU'));
--   select * from public.logs where cat = 'anticheat' order by t desc limit 50;
-- Change a limit (no deploy needed): update public.anticheat_limits set per_hour = 60 where key = 'km';
-- Clear a player after review:      update public.player_state set suspect_score = 0, reasons = '[]' where user_id = '...';

create table if not exists public.player_state (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  saves         bigint      not null default 0,     -- accepted writes seen since this file was run
  rate_limited  bigint      not null default 0,     -- writes refused for coming too soon
  counters      jsonb       not null default '{}',  -- {key: value} from the last accepted save (anticheat_limits keys)
  god_at        timestamptz,                        -- a save said GOD MODE was used; never cleared by the game
  god_log_at    timestamptz,                        -- tester tools showed up in the logs
  suspect_score int         not null default 0,
  reasons       jsonb       not null default '[]',  -- last 20 {at, key, gain, allowed, dt, rev}
  updated_at    timestamptz not null default now()
);
alter table public.player_state enable row level security;   -- no policies: functions below / SQL Editor only

-- One row per counter. path = where the number sits in the save envelope {v, account, main}.
-- allowed gain between two saves = per_hour * hours of real (server) time between them + slack.
create table if not exists public.anticheat_limits (
  key      text primary key,
  path     text[]  not null,
  per_hour numeric not null,
  slack    numeric not null,
  note     text
);
alter table public.anticheat_limits enable row level security;

-- Numbers from the balance bot (tools/balance.gd, 240 min, 2026-10-24): about 3 km and 450 kills per played hour.
-- The limits sit several times above that so upgrades and lucky streaks never trip them.
insert into public.anticheat_limits (key, path, per_hour, slack, note) values
  ('sim_sec', '{account,life,sim_sec}', 3600 * 1.1, 900, 'simulated seconds can not grow faster than the clock (+10%, +15 min for upload lag)'),
  ('km',      '{main,stats,km_total}',  40,         5,   'balance bot: ~3 km per hour; base speed 6 km/h'),
  ('kills',   '{main,combat,kills}',    6000,       500, 'balance bot: ~450 per hour; offline pays at most 30 per minute'),
  ('gen',     '{account,meta,gen}',     3,          1,   'Next Generation needs a whole run')
on conflict (key) do update set path = excluded.path, per_hour = excluded.per_hour, slack = excluded.slack, note = excluded.note;


-- F1: compare the new save with the last one; returns the number of counters over their limit.
-- Called by rpc_save only (players can't call it).
create or replace function public.anticheat_check(p_uid uuid, p_data jsonb, p_prev_at timestamptz, p_rev bigint)
returns int language plpgsql security definer set search_path = '' as $$
declare
  st public.player_state%rowtype;
  lim record;
  dt numeric;
  v numeric; old numeric; gain numeric; allowed numeric;
  newc jsonb := '{}'::jsonb;
  found_reasons jsonb := '[]'::jsonb;
  god boolean;
begin
  insert into public.player_state (user_id) values (p_uid) on conflict do nothing;
  select * into st from public.player_state where user_id = p_uid for update;
  dt := case when p_prev_at is null then null else greatest(0, extract(epoch from now() - p_prev_at)) end;

  for lim in select * from public.anticheat_limits loop
    if jsonb_typeof(p_data #> lim.path) <> 'number' then
      continue;
    end if;
    v := (p_data #>> lim.path)::numeric;
    newc := newc || jsonb_build_object(lim.key, v);
    old := (st.counters ->> lim.key)::numeric;
    if dt is null or old is null then
      continue;      -- first save we see for this player: it only becomes the baseline
    end if;
    gain := case when v < old then v else v - old end;   -- went down = new vehicle / generation: count from 0
    allowed := lim.per_hour * dt / 3600 + lim.slack;
    if gain > allowed then
      found_reasons := found_reasons || jsonb_build_object('at', extract(epoch from now()), 'key', lim.key,
        'gain', round(gain, 2), 'allowed', round(allowed, 2), 'dt', round(dt), 'rev', p_rev);
    end if;
  end loop;

  god := coalesce(p_data #> '{main,stats,cheated}' = 'true'::jsonb, false)
      or coalesce(p_data #> '{account,life,cheated}' = 'true'::jsonb, false)
      or coalesce(p_data #> '{event,stats,cheated}' = 'true'::jsonb, false);

  update public.player_state set
    saves = saves + 1,
    counters = st.counters || newc,
    god_at = case when god then coalesce(god_at, now()) else god_at end,
    suspect_score = suspect_score + jsonb_array_length(found_reasons),
    reasons = case when jsonb_array_length(found_reasons) = 0 then reasons else
      (select coalesce(jsonb_agg(x order by n), '[]'::jsonb) from (
         select x, n from jsonb_array_elements(reasons || found_reasons) with ordinality as e(x, n)
         order by n desc limit 20) last20) end,
    updated_at = now()
  where user_id = p_uid;

  if jsonb_array_length(found_reasons) > 0 or (god and st.god_at is null) then
    insert into public.logs (user_id, player_id, session, t, cat, msg, data, game_version)
    values (p_uid, public.player_id(p_uid), 'server', now(), 'anticheat',
      case when jsonb_array_length(found_reasons) > 0 then 'suspect save: ' ||
        (select string_agg(r ->> 'key', ', ') from jsonb_array_elements(found_reasons) r) else 'god mode seen in save' end,
      jsonb_build_object('reasons', found_reasons, 'god', god, 'rev', p_rev), null);
  end if;
  return jsonb_array_length(found_reasons);
end $$;


-- rpc_save from 0002 + rate limit + F1 check. Now security definer (it writes player_state, which players can't
-- touch); every statement still works only on the caller's own row (auth.uid()).
create or replace function public.rpc_save(
  p_base_rev bigint, p_data jsonb, p_settings jsonb,
  p_schema int, p_game_version text, p_device_id text, p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cur public.saves%rowtype;
  min_gap constant numeric := 3;   -- seconds between two accepted writes (the game uploads once a minute)
  since numeric;
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
    perform public.anticheat_check(uid, p_data, null, 1);
    return jsonb_build_object('ok', true, 'rev', 1, 'server_time', extract(epoch from now()));
  end if;
  if coalesce(p_schema, 1) < cur.schema_version then
    return jsonb_build_object('ok', false, 'old_client', true, 'rev', cur.rev,
      'schema_version', cur.schema_version, 'server_time', extract(epoch from now()));
  end if;
  if not p_force and cur.rev <> p_base_rev then
    return jsonb_build_object('ok', false, 'conflict', true, 'rev', cur.rev,
      'device_id', cur.device_id, 'updated_at', extract(epoch from cur.updated_at),
      'server_time', extract(epoch from now()));
  end if;
  since := extract(epoch from now() - cur.updated_at);
  if since < min_gap then
    insert into public.player_state (user_id, rate_limited) values (uid, 1)
    on conflict (user_id) do update set rate_limited = public.player_state.rate_limited + 1;
    return jsonb_build_object('ok', false, 'rate_limited', true, 'retry_after', round(min_gap - since, 1),
      'rev', cur.rev, 'server_time', extract(epoch from now()));
  end if;
  update public.saves set rev = cur.rev + 1, schema_version = p_schema, game_version = p_game_version,
    device_id = p_device_id, data = p_data, settings = coalesce(p_settings, settings), updated_at = now()
  where user_id = uid;
  perform public.anticheat_check(uid, p_data, cur.updated_at, cur.rev + 1);
  return jsonb_build_object('ok', true, 'rev', cur.rev + 1, 'server_time', extract(epoch from now()));
end $$;


-- Tester tools in the logs (Trace category 'god'): remember when they first showed up. Read-only god actions
-- (log flush, copy player id, the anti-cheat tests) don't count.
create or replace function public.anticheat_on_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.cat = 'god' and new.msg not in ('logs flush', 'copy player id', 'anticheat time test', 'anticheat rate test') then
    insert into public.player_state (user_id, god_log_at) values (new.user_id, now())
    on conflict (user_id) do update set god_log_at = coalesce(public.player_state.god_log_at, now());
  end if;
  return new;
end $$;

drop trigger if exists anticheat_god_log on public.logs;
create trigger anticheat_god_log after insert on public.logs
  for each row when (new.cat = 'god') execute function public.anticheat_on_log();


create or replace view public.anticheat_suspects as
  select public.player_id(p.user_id) as player_id, p.suspect_score, p.god_at, p.god_log_at, p.rate_limited, p.saves,
         p.reasons -> -1 as last_reason, p.counters, s.game_version, s.updated_at as last_save, p.user_id
  from public.player_state p
  left join public.saves s on s.user_id = p.user_id
  where p.suspect_score > 0 or p.god_at is not null or p.god_log_at is not null
  order by greatest(p.updated_at, coalesce(p.god_log_at, p.updated_at)) desc;


revoke all on function public.anticheat_check(uuid, jsonb, timestamptz, bigint) from public, anon, authenticated;
revoke all on function public.anticheat_on_log() from public, anon, authenticated;
revoke all on public.anticheat_suspects from public, anon, authenticated;
revoke all on public.player_state, public.anticheat_limits from anon, authenticated;
revoke all on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) from public, anon;
grant execute on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) to authenticated;
