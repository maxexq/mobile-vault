-- MV-569: durable server-side forwarding of new activity/error logs to Sentry.
-- Deploy after 0001-0006. Disabled until an owner explicitly enables it in SQL Editor.
-- No DSN, service key or historical backfill is stored in this migration.
create table if not exists public.sentry_forward_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false
);
insert into public.sentry_forward_config (singleton) values (true) on conflict do nothing;

create table if not exists public.sentry_log_outbox (
  log_id bigint primary key references public.logs(id) on delete cascade,
  worker uuid,
  lease_until timestamptz,
  attempts integer not null default 0,
  delivered_at timestamptz,
  last_error text
);
create index if not exists sentry_outbox_pending on public.sentry_log_outbox(log_id)
  where delivered_at is null;
alter table public.sentry_forward_config enable row level security;
alter table public.sentry_log_outbox enable row level security;
revoke all on public.sentry_forward_config, public.sentry_log_outbox from public, anon, authenticated;
grant select, update on public.sentry_forward_config to service_role;
grant select on public.sentry_log_outbox to service_role;

create or replace function public.enqueue_sentry_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.cat in ('activity', 'error') and exists (
    select 1 from public.sentry_forward_config where singleton and enabled
  ) then
    insert into public.sentry_log_outbox(log_id) values (new.id) on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.enqueue_sentry_log() from public, anon, authenticated;
drop trigger if exists enqueue_sentry_log on public.logs;
create trigger enqueue_sentry_log after insert on public.logs
  for each row execute function public.enqueue_sentry_log();

-- Claim independently committed rows, rather than a sequence checkpoint which can skip
-- an earlier ID whose transaction commits late. Expired leases retry after worker crashes.
create or replace function public.sentry_claim(p_worker uuid, p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if p_worker is null then raise exception 'worker required'; end if;
  if not exists (select 1 from public.sentry_forward_config where singleton and enabled) then
    return '[]'::jsonb;
  end if;
  with candidates as (
    select q.log_id from public.sentry_log_outbox q
    where q.delivered_at is null and (q.lease_until is null or q.lease_until < now())
    order by q.log_id limit greatest(1, least(100, p_limit)) for update skip locked
  ), claimed as (
    update public.sentry_log_outbox q set worker = p_worker,
      lease_until = now() + interval '5 minutes', attempts = q.attempts + 1
    from candidates c where q.log_id = c.log_id returning q.log_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.id, 'player_id', l.player_id, 'session', l.session, 't', l.t,
    'cat', l.cat, 'msg', l.msg, 'data', l.data, 'game_version', l.game_version
  ) order by l.id), '[]'::jsonb) into result
  from claimed c join public.logs l on l.id = c.log_id;
  return result;
end $$;

create or replace function public.sentry_ack(p_worker uuid, p_ids bigint[])
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  update public.sentry_log_outbox set delivered_at = now(), worker = null,
    lease_until = null, last_error = null
  where log_id = any(p_ids) and worker = p_worker and lease_until > now() and delivered_at is null;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.sentry_retry(p_worker uuid, p_ids bigint[], p_delay integer default 60)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  update public.sentry_log_outbox set worker = null,
    lease_until = now() + make_interval(secs => greatest(30, least(3600, p_delay))),
    last_error = 'Sentry delivery not acknowledged'
  where log_id = any(p_ids) and worker = p_worker and delivered_at is null;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.sentry_claim(uuid, integer) from public, anon, authenticated;
revoke all on function public.sentry_ack(uuid, bigint[]) from public, anon, authenticated;
revoke all on function public.sentry_retry(uuid, bigint[], integer) from public, anon, authenticated;
grant execute on function public.sentry_claim(uuid, integer) to service_role;
grant execute on function public.sentry_ack(uuid, bigint[]) to service_role;
grant execute on function public.sentry_retry(uuid, bigint[], integer) to service_role;
