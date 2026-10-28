-- Checks supabase/migrations/0005_log_alerts.sql (MV-171) on a plain PostgreSQL with 0001-0005 applied
-- and a stub auth schema; run by tools/test_error_spike.sh. Fails (exception) on the first wrong answer.
do $$
declare r jsonb; u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
begin
  truncate public.logs, public.log_alerts cascade;
  insert into auth.users (id) values (u1), (u2), (u3) on conflict do nothing;

  -- baseline: one old error per hour for the last day
  insert into public.logs (user_id, player_id, session, t, cat, msg, data, game_version)
    select u1, 'P1', 's', now() - make_interval(hours => h), 'error', 'Old thing (a.gd:' || h || ' f)', '{"kind":"error"}', '4.7.0-alpha.1'
    from generate_series(2, 25) h;
  r := public.log_alert_check();
  assert not (r->>'spike')::boolean, 'quiet day must not spike: ' || r::text;
  assert jsonb_array_length(r->'new') = 0, 'nothing new in the window: ' || r::text;

  -- 30 errors in the last hour from 3 players: the old message plus a new one with changing line numbers
  insert into public.logs (user_id, player_id, session, t, cat, msg, data, game_version)
    select (array[u1, u2, u3])[1 + i % 3], 'P' || (1 + i % 3), 's', now() - make_interval(mins => i),
           'error', case when i % 2 = 0 then 'Old thing (a.gd:' || i || ' f)' else 'Invalid get index (b.gd:' || i || ' g)' end,
           '{"kind":"script"}', '4.7.0-alpha.2'
    from generate_series(1, 30) i;
  -- warnings and GOD test errors don't count by default
  insert into public.logs (user_id, player_id, session, t, cat, msg, data)
    select u1, 'P1', 's', now(), 'error', 'noise', jsonb_build_object('kind', k)
    from unnest(array['warning', 'test']) k, generate_series(1, 50);

  r := public.log_alert_check();
  assert (r->>'spike')::boolean, 'spike expected: ' || r::text;
  assert (r->>'errors')::int = 30 and (r->>'players')::int = 3, 'counts: ' || r::text;
  assert jsonb_array_length(r->'new') = 1 and r->'new'->0->>'fp' = 'Invalid get index (b.gd:# g)', 'one new fp: ' || r::text;
  assert (r->'new'->0->>'n')::int = 15, 'new error count: ' || r::text;
  assert r->'versions'->>'4.7.0-alpha.2' = '30', 'versions: ' || r::text;

  r := public.log_alert_check(p_include_test => true);
  assert (r->>'errors')::int = 80, 'test errors counted when asked: ' || r::text;
  r := public.log_alert_check(p_kinds => array['warning']);
  assert (r->>'errors')::int = 50 and not (r->>'spike')::boolean, 'warnings only, 1 player: ' || r::text;

  -- thresholds are parameters
  r := public.log_alert_check(p_min_errors => 31);
  assert not (r->>'spike')::boolean, 'below min_errors: ' || r::text;
  r := public.log_alert_check(p_min_players => 4);
  assert not (r->>'spike')::boolean, 'below min_players: ' || r::text;
  r := public.log_alert_check(p_ratio => 31);
  assert not (r->>'spike')::boolean, 'below ratio: ' || r::text;

  -- after the ack: cooldown holds the spike, the new error is not new any more
  r := public.log_alert_ack(true, array['Invalid get index (b.gd:# g)'], '{"errors":30}');
  assert (r->>'new')::int = 1, 'ack: ' || r::text;
  r := public.log_alert_ack(false, array['Invalid get index (b.gd:# g)']);
  assert (r->>'new')::int = 0, 'second ack of the same fp is a no-op: ' || r::text;
  r := public.log_alert_check();
  assert not (r->>'spike')::boolean and r->>'last_spike_alert' is not null, 'cooldown: ' || r::text;
  assert jsonb_array_length(r->'new') = 0, 'acked fp is not new: ' || r::text;
  r := public.log_alert_check(p_cooldown_min => 0);
  assert (r->>'spike')::boolean, 'cooldown 0 posts again: ' || r::text;

  -- players can't call either function
  assert not has_function_privilege('authenticated', 'public.log_alert_check(int,int,int,numeric,int,int,int,text[],boolean,int)', 'execute'), 'authenticated can check';
  assert not has_function_privilege('anon', 'public.log_alert_ack(boolean,text[],jsonb)', 'execute'), 'anon can ack';
  assert has_function_privilege('service_role', 'public.log_alert_ack(boolean,text[],jsonb)', 'execute'), 'service_role cannot ack';
  assert not has_table_privilege('authenticated', 'public.log_alerts', 'select'), 'authenticated can read log_alerts';

  truncate public.logs, public.log_alerts cascade;
  null;  -- every assert passed
end $$;
