-- Mobile Vault: short public player id (MV-115). Run once in Supabase > SQL Editor, after 0002.
-- The game shows each player an id like 0G3SQ-MSKUU (Settings > เซฟ, copy button). It is not stored: it is
-- the first 48 bits of the auth user id written in base32, computed the same way by Cloud.short_id()
-- (scripts/autoload/cloud.gd). Alphabet = Crockford with U for D: 0123456789ABCEFGHJKMNPQRSTUVWXYZ.
-- Support only: both functions are for the SQL Editor (postgres role); players can't call them.
--
-- Check after running (same vector as the autotest):
--   select public.player_id('0f1e2d3c-4b5a-4987-8a6b-5c4d3e2f1a0b');   -- 0G3SQ-MSKUU
-- Look a player up from what they typed or read out (case, dashes, O/D for 0 and I/L for 1 are forgiven):
--   select * from public.find_player('og3sq mskuu');   -- finds 0G3SQ-MSKUU

create or replace function public.player_id(p_user uuid) returns text
language plpgsql immutable as $$
declare
  n bigint := ('x' || lpad(left(replace(p_user::text, '-', ''), 12), 16, '0'))::bit(64)::bigint;
  chars constant text := '0123456789ABCEFGHJKMNPQRSTUVWXYZ';
  s text := '';
begin
  for i in 1..10 loop
    s := substr(chars, (n & 31)::int + 1, 1) || s;
    n := n >> 5;
  end loop;
  return left(s, 5) || '-' || right(s, 5);
end $$;

create or replace function public.find_player(p_id text)
returns table (user_id uuid, player_id text, email text, rev bigint, game_version text, updated_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select u.id, public.player_id(u.id), u.email::text, s.rev, s.game_version, s.updated_at
  from auth.users u
  left join public.saves s on s.user_id = u.id
  where replace(public.player_id(u.id), '-', '') =
        translate(upper(regexp_replace(p_id, '[^0-9A-Za-z]', '', 'g')), 'ODIL', '0011');
$$;

revoke all on function public.player_id(uuid) from public, anon, authenticated;
revoke all on function public.find_player(text) from public, anon, authenticated;
