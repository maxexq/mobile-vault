-- Mobile Vault: error spike alerts from player logs (MV-171). Run once in Supabase > SQL Editor, after 0004.
-- The GitHub workflow "Error spike" (.github/workflows/error-spike.yml) calls log_alert_check() every 15 minutes
-- with the service_role / secret key, posts to Discord when it says so, then calls log_alert_ack() so the same
-- spike or the same new error is not posted again. Players can't call either function.
--
-- Two kinds of alert:
--   spike  errors in the last p_window_min minutes >= p_min_errors, hit >= p_min_players players, and are
--          >= p_ratio x the average per window over the p_baseline_hours before it. Posted again only after
--          p_cooldown_min minutes.
--   new    an error message (digits folded to #, so line numbers / ids don't make "new" errors) that never showed
--          up in the p_new_days days before the window. Each fingerprint is posted once.
-- Warnings (kind 'warning') and GOD test errors (kind 'test') don't count unless asked for (p_kinds / p_include_test).
--
-- Try it by hand (read-only, nothing is recorded):
--   select public.log_alert_check();
--   select public.log_alert_check(p_window_min => 1440, p_min_errors => 1, p_min_players => 1, p_include_test => true);
-- Alert history: select * from public.log_alerts order by at desc;
-- Forget everything (next run treats all current errors as new again): truncate public.log_alerts;

create table if not exists public.log_alerts (
  id     bigint generated always as identity primary key,
  at     timestamptz not null default now(),
  kind   text        not null,          -- 'spike' or 'new'
  fp     text,                          -- fingerprint for 'new', null for 'spike'
  detail jsonb
);
create index if not exists log_alerts_kind_at on public.log_alerts (kind, at desc);
create unique index if not exists log_alerts_new_fp on public.log_alerts (fp) where kind = 'new';
alter table public.log_alerts enable row level security;   -- no policies: service role / SQL Editor only

-- same message with different numbers (line, id, count) = same error
create or replace function public.log_fp(p_msg text) returns text
language sql immutable as $$
  select left(regexp_replace(coalesce(p_msg, ''), '[0-9]+', '#', 'g'), 160);
$$;

create index if not exists logs_error_t on public.logs (t desc) where cat = 'error';

create or replace function public.log_alert_check(
  p_window_min     int     default 60,
  p_min_errors     int     default 20,
  p_min_players    int     default 2,
  p_ratio          numeric default 3,
  p_baseline_hours int     default 24,
  p_cooldown_min   int     default 60,
  p_new_days       int     default 7,
  p_kinds          text[]  default array['error', 'script', 'shader'],
  p_include_test   boolean default false,
  p_top            int     default 5
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  w_end   timestamptz := now();
  w_start timestamptz := now() - make_interval(mins => p_window_min);
  b_start timestamptz := w_start - make_interval(hours => p_baseline_hours);
  n_err int; n_players int; n_base int; base_per_window numeric;
  last_spike timestamptz;
  spike boolean := false;
  top jsonb; new_errs jsonb; versions jsonb;
begin
  -- the errors this check looks at (window + baseline + "new" lookback), gone at the end of the transaction
  if to_regclass('pg_temp._errs') is null then
    create temporary table _errs (t timestamptz, player_id text, game_version text, msg text, fp text) on commit drop;
  else
    truncate _errs;
  end if;
  insert into _errs
    select l.t, l.player_id, l.game_version, l.msg, public.log_fp(l.msg)
    from public.logs l
    where l.cat = 'error'
      and l.t >= least(b_start, w_start - make_interval(days => p_new_days)) and l.t <= w_end
      and (coalesce(l.data->>'kind', 'error') = any(p_kinds)
           or (p_include_test and l.data->>'kind' = 'test'));

  select count(*), count(distinct player_id) into n_err, n_players from _errs where t >= w_start;
  select count(*) into n_base from _errs where t >= b_start and t < w_start;
  base_per_window := n_base::numeric * p_window_min / (p_baseline_hours * 60);
  select max(at) into last_spike from public.log_alerts where kind = 'spike';

  spike := n_err >= p_min_errors and n_players >= p_min_players
           and n_err >= p_ratio * base_per_window
           and (last_spike is null or last_spike <= now() - make_interval(mins => p_cooldown_min));

  select coalesce(jsonb_agg(x order by x.n desc), '[]') into top from (
    select fp, max(msg) as msg, count(*) as n, count(distinct player_id) as players
    from _errs where t >= w_start group by fp order by n desc limit p_top) x;

  select coalesce(jsonb_agg(x order by x.first_t), '[]') into new_errs from (
    select e.fp, max(e.msg) as msg, count(*) as n, count(distinct e.player_id) as players,
           min(e.t) as first_t, max(e.game_version) as game_version
    from _errs e
    where e.t >= w_start
      and not exists (select 1 from _errs o where o.fp = e.fp and o.t < w_start
                      and o.t >= w_start - make_interval(days => p_new_days))
      and not exists (select 1 from public.log_alerts a where a.kind = 'new' and a.fp = e.fp)
    group by e.fp order by min(e.t) limit p_top) x;

  select coalesce(jsonb_object_agg(v, n), '{}') into versions from (
    select coalesce(game_version, '?') as v, count(*) as n from _errs where t >= w_start group by 1) x;

  return jsonb_build_object(
    'spike', spike,
    'window_min', p_window_min, 'errors', n_err, 'players', n_players,
    'baseline_per_window', round(base_per_window, 1), 'baseline_hours', p_baseline_hours,
    'ratio', case when base_per_window > 0 then round(n_err / base_per_window, 1) end,
    'last_spike_alert', last_spike,
    'versions', versions, 'top', top, 'new', new_errs,
    'checked_at', w_end);
end $$;

-- record what was posted: p_spike = a spike message went out, p_new_fps = fingerprints of the new errors posted
create or replace function public.log_alert_ack(p_spike boolean, p_new_fps text[] default '{}', p_detail jsonb default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare n int := 0;
begin
  if p_spike then
    insert into public.log_alerts (kind, detail) values ('spike', p_detail);
  end if;
  insert into public.log_alerts (kind, fp)
    select 'new', f from unnest(coalesce(p_new_fps, '{}')) f
    on conflict (fp) where kind = 'new' do nothing;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'spike', p_spike, 'new', n);
end $$;

revoke all on table public.log_alerts from public, anon, authenticated;
revoke all on function public.log_fp(text) from public, anon, authenticated;
revoke all on function public.log_alert_check(int, int, int, numeric, int, int, int, text[], boolean, int) from public, anon, authenticated;
revoke all on function public.log_alert_ack(boolean, text[], jsonb) from public, anon, authenticated;
grant execute on function public.log_alert_check(int, int, int, numeric, int, int, int, text[], boolean, int) to service_role;
grant execute on function public.log_alert_ack(boolean, text[], jsonb) to service_role;
