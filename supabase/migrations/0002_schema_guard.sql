-- Mobile Vault: refuse saves from older game builds (run once in Supabase > SQL Editor, after 0001).
-- Schema 2 (MV-159) wraps the save as {v: 2, account, main}. A tab still running an older build reads that
-- as "no save", starts a fresh run and would upload it over the account. From now on a write whose
-- p_schema is lower than the row's schema_version is refused with {ok:false, old_client:true}; the old
-- client keeps its local copy and the cloud row stays untouched. p_force does not bypass the guard.

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
  if coalesce(p_schema, 1) < cur.schema_version then
    return jsonb_build_object('ok', false, 'old_client', true, 'rev', cur.rev,
      'schema_version', cur.schema_version, 'server_time', extract(epoch from now()));
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

revoke all on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) from public, anon;
grant execute on function public.rpc_save(bigint, jsonb, jsonb, int, text, text, boolean) to authenticated;
