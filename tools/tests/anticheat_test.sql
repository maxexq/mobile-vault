-- Checks supabase/migrations/0006_anticheat.sql (MV-174) on a plain PostgreSQL with 0001-0006 applied and a stub
-- auth schema; run by tools/test_error_spike.sh. Fails (exception) on the first wrong answer.
-- auth.uid() is pointed at a setting so the test can be "signed in"; "time passes" by moving saves.updated_at back.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid $$;

create or replace function pg_temp.env(sim numeric, km numeric, kills int, gen int, cheated boolean default false)
returns jsonb language sql as $$
  select jsonb_build_object('v', 2,
    'account', jsonb_build_object('life', jsonb_build_object('sim_sec', sim), 'meta', jsonb_build_object('gen', gen)),
    'main', jsonb_build_object('rooms', '[]'::jsonb, 'stats', jsonb_build_object('km_total', km, 'cheated', cheated),
                               'combat', jsonb_build_object('kills', kills)))
$$;

-- "hours" of real time pass for this player before the next write
create or replace function pg_temp.later(u uuid, hours numeric) returns void language sql as $$
  update public.saves set updated_at = updated_at - make_interval(secs => hours * 3600) where user_id = u
$$;

create or replace function pg_temp.save(rev bigint, data jsonb, force boolean default false) returns jsonb language sql as $$
  select public.rpc_save(rev, data, '{}'::jsonb, 2, '4.7.0-test', 'dev', force)
$$;

do $$
declare r jsonb; u uuid := gen_random_uuid(); g uuid := gen_random_uuid(); st public.player_state%rowtype;
begin
  insert into auth.users (id) values (u), (g);
  perform set_config('test.uid', u::text, false);

  -- first save: becomes the baseline, never flagged, even with big numbers (an old local save going up)
  r := pg_temp.save(0, pg_temp.env(50000, 300, 20000, 4));
  assert (r->>'ok')::boolean and (r->>'rev')::int = 1, 'first save: ' || r::text;
  select * into st from public.player_state where user_id = u;
  assert st.saves = 1 and st.suspect_score = 0, 'baseline only: ' || row_to_json(st)::text;
  assert (st.counters->>'km')::numeric = 300 and (st.counters->>'sim_sec')::numeric = 50000, 'counters kept: ' || st.counters::text;

  -- a write right after the last one is refused, the row stays as it was
  r := pg_temp.save(1, pg_temp.env(50001, 300, 20000, 4));
  assert not (r->>'ok')::boolean and (r->>'rate_limited')::boolean, 'rate limit: ' || r::text;
  assert (select rev from public.saves where user_id = u) = 1, 'refused write changed nothing';
  assert (select rate_limited from public.player_state where user_id = u) = 1, 'rate limit counted';

  -- a normal hour: 1 h of sim, 3 km, 450 kills -> clean
  perform pg_temp.later(u, 1);
  r := pg_temp.save(1, pg_temp.env(53600, 303, 20450, 4));
  assert (r->>'ok')::boolean, 'normal save: ' || r::text;
  assert (select suspect_score from public.player_state where user_id = u) = 0, 'normal hour is clean';

  -- conflicts still win over the rate limit check order (stale rev = conflict, not rate limited)
  r := pg_temp.save(1, pg_temp.env(53600, 303, 20450, 4));
  assert (r->>'conflict')::boolean, 'stale rev is a conflict: ' || r::text;

  -- saved_at moved back 4 h + reload: 4 h of sim show up after 10 real minutes -> flagged, but saved
  perform pg_temp.later(u, 10.0 / 60);
  r := pg_temp.save(2, pg_temp.env(53600 + 4 * 3600 + 600, 304, 20500, 4));
  assert (r->>'ok')::boolean and (r->>'rev')::int = 3, 'suspect save is still accepted: ' || r::text;
  select * into st from public.player_state where user_id = u;
  assert st.suspect_score = 1 and st.reasons->0->>'key' = 'sim_sec', 'time jump flagged: ' || row_to_json(st)::text;
  assert exists (select 1 from public.logs where user_id = u and cat = 'anticheat' and msg like 'suspect save: sim_sec%'), 'anticheat log row';

  -- edited kills + km in one go: two reasons
  perform pg_temp.later(u, 0.5);
  r := pg_temp.save(3, pg_temp.env(53600 + 4 * 3600 + 600 + 1800, 900, 99999, 4));
  select * into st from public.player_state where user_id = u;
  assert st.suspect_score = 3 and jsonb_array_length(st.reasons) = 3, 'km + kills flagged: ' || row_to_json(st)::text;

  -- a new generation: km and kills start again from 0, gen +1 -> clean
  perform pg_temp.later(u, 2);
  r := pg_temp.save(4, pg_temp.env(53600 + 4 * 3600 + 600 + 1800 + 7200, 5, 300, 5));
  assert (select suspect_score from public.player_state where user_id = u) = 3, 'reset counters are not a jump';

  -- GOD MODE in the save: sticky, stays after the flag is removed from the save
  perform pg_temp.later(u, 0.1);
  r := pg_temp.save(5, pg_temp.env(53600 + 4 * 3600 + 600 + 1800 + 7200 + 360, 5.5, 310, 5, true));
  assert (select god_at from public.player_state where user_id = u) is not null, 'god flag set';
  perform pg_temp.later(u, 0.1);
  r := pg_temp.save(6, pg_temp.env(53600 + 4 * 3600 + 600 + 1800 + 7200 + 720, 6, 320, 5, false));
  assert (r->>'ok')::boolean and (select god_at from public.player_state where user_id = u) is not null, 'god flag is sticky';
  assert (select count(*) from public.logs where user_id = u and msg = 'god mode seen in save') = 1, 'god logged once';

  -- tester tools in the logs: only real god actions count
  insert into public.logs (user_id, player_id, session, t, cat, msg) values (g, 'G', 's', now(), 'god', 'logs flush');
  assert not exists (select 1 from public.player_state where user_id = g and god_log_at is not null), 'read-only god action ignored';
  insert into public.logs (user_id, player_id, session, t, cat, msg) values (g, 'G', 's', now(), 'god', 'add scrap');
  assert (select god_log_at from public.player_state where user_id = g) is not null, 'god action in logs flagged';

  -- the dashboard view lists both, players can't read any of it
  assert (select count(*) from public.anticheat_suspects where user_id in (u, g)) = 2, 'suspects view';
  assert not has_table_privilege('authenticated', 'public.player_state', 'select'), 'players cannot read player_state';
  assert not has_table_privilege('authenticated', 'public.anticheat_suspects', 'select'), 'players cannot read the view';
  assert not has_function_privilege('authenticated', 'public.anticheat_check(uuid, jsonb, timestamptz, bigint)', 'execute'), 'players cannot call the check';
  assert has_function_privilege('authenticated', 'public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean)', 'execute'), 'players can still save';

  -- reasons keep only the last 20
  for i in 1..25 loop
    perform pg_temp.later(u, 0.01);
    r := pg_temp.save(6 + i, pg_temp.env(100000 + i * 100000, 6, 320, 5));
  end loop;
  assert jsonb_array_length((select reasons from public.player_state where user_id = u)) = 20, 'reasons capped at 20';
end $$;
