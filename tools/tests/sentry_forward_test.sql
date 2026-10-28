-- Disposable test database only; transaction rolls back all fixture data.
begin;
do $$
declare u uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  rows jsonb; ids bigint[]; n integer;
begin
  insert into auth.users(id) values(u);
  update public.sentry_forward_config set enabled = false;
  insert into public.logs(user_id,player_id,session,t,cat,msg)
    values(u,'DEMO','s',now(),'activity','disabled');
  assert not exists(select 1 from public.sentry_log_outbox), 'disabled must not enqueue';
  update public.sentry_forward_config set enabled = true;
  insert into public.logs(user_id,player_id,session,t,cat,msg)
    values(u,'DEMO','s',now(),'activity','a'),(u,'DEMO','s',now(),'error','b'),
          (u,'DEMO','s',now(),'sample','skip');
  assert (select count(*) from public.sentry_log_outbox) = 2, 'only activity/error';
  rows := public.sentry_claim(a,100);
  assert jsonb_array_length(rows) = 2, 'claim both rows';
  assert not (rows->0 ? 'user_id'), 'private auth UUID must not reach worker';
  assert public.sentry_claim(b,100) = '[]'::jsonb, 'worker leases exclude each other';
  select array_agg((x->>'id')::bigint) into ids from jsonb_array_elements(rows) x;
  assert public.sentry_ack(b,ids) = 0, 'other worker cannot acknowledge';
  assert public.sentry_retry(a,ids,30) = 2, 'failed delivery remains retryable';
  assert public.sentry_claim(b,100) = '[]'::jsonb, 'backoff respected';
  update public.sentry_log_outbox set lease_until = now() - interval '1 second';
  rows := public.sentry_claim(b,100);
  assert jsonb_array_length(rows) = 2, 'expired lease retries';
  assert public.sentry_ack(b,ids) = 2, 'own delivery acknowledged';
  assert public.sentry_claim(a,100) = '[]'::jsonb, 'acknowledged rows do not resend';
  update public.sentry_forward_config set enabled = false;
  assert public.sentry_claim(a,100) = '[]'::jsonb, 'server kill switch respected';
  assert not has_function_privilege('authenticated','public.sentry_claim(uuid,integer)','EXECUTE'), 'players cannot claim';
  assert not has_function_privilege('anon','public.sentry_ack(uuid,bigint[])','EXECUTE'), 'anonymous cannot ack';
end $$;
rollback;
