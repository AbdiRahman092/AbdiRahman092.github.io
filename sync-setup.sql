-- Gym Designer · cross-device sync
-- Run once in the Supabase SQL editor:
--   https://supabase.com/dashboard/project/rdienquzpfwfdgxfkzmq/sql/new
-- Safe to re-run (idempotent). Only touches its own table; nothing else in Mentis.

create table if not exists public.gym_layouts (
  slug       text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

-- Lock the table down: no direct anon/authenticated access at all.
alter table public.gym_layouts enable row level security;
-- (intentionally NO policies -> only the SECURITY DEFINER functions below can read/write)

-- Load a layout by its exact slug (returns null if none).
create or replace function public.gym_load(p_slug text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select data from public.gym_layouts where slug = p_slug;
$$;

-- Upsert a layout by slug (last write wins).
create or replace function public.gym_save(p_slug text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(p_slug) < 6 or length(p_slug) > 64 then
    raise exception 'bad slug';
  end if;
  insert into public.gym_layouts (slug, data, updated_at)
  values (p_slug, p_data, now())
  on conflict (slug) do update
    set data = excluded.data, updated_at = now();
end;
$$;

-- Only the functions are callable by the public anon key; the table stays sealed.
revoke all on function public.gym_load(text)         from public;
revoke all on function public.gym_save(text, jsonb)  from public;
grant execute on function public.gym_load(text)        to anon, authenticated;
grant execute on function public.gym_save(text, jsonb) to anon, authenticated;
