-- =============================================================================
-- Finku: Profiles Avatar, Storage Bucket (`avatars`), Trigger & Shared Wallet RBAC
-- =============================================================================

-- 1. Tambahkan kolom avatar_url pada public.profiles
alter table public.profiles
  add column if not exists avatar_url text;

-- 2. Kebijakan RLS tambahan untuk INSERT profil sendiri (upsert aman)
drop policy if exists "Pengguna dapat membuat profil sendiri" on public.profiles;
create policy "Pengguna dapat membuat profil sendiri"
  on public.profiles for insert
  to authenticated
  with check (id = (select auth.uid()));

drop policy if exists "Pengguna hanya dapat mengubah profil sendiri" on public.profiles;
create policy "Pengguna hanya dapat mengubah profil sendiri"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- 3. Perbarui fungsi trigger on_auth_user_created untuk Email & Google Sign-In
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_initials text;
  v_avatar_url text;
  v_personal_wallet_id uuid;
begin
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Pengguna Finku'
  );

  v_avatar_url := coalesce(
    nullif(trim(new.raw_user_meta_data->>'avatar_url'), ''),
    nullif(trim(new.raw_user_meta_data->>'picture'), '')
  );

  v_initials := upper(left(regexp_replace(v_name, '[^a-zA-Z]', '', 'g'), 2));
  if length(v_initials) = 0 then
    v_initials := 'FK';
  end if;

  insert into public.profiles (id, email, full_name, avatar_initials, avatar_url)
  values (new.id, coalesce(new.email, ''), v_name, v_initials, v_avatar_url)
  on conflict (id) do update
    set email = coalesce(nullif(excluded.email, ''), profiles.email),
        full_name = coalesce(nullif(excluded.full_name, ''), profiles.full_name),
        avatar_url = coalesce(profiles.avatar_url, excluded.avatar_url),
        updated_at = now();

  -- Buat 1 Dompet Pribadi default jika user belum memilikinya
  if not exists (
    select 1
    from public.wallets w
    join public.wallet_members wm on wm.wallet_id = w.id
    where wm.user_id = new.id
      and w.is_shared = false
  ) then
    insert into public.wallets (name, is_shared, created_by)
    values ('Dompet Pribadi', false, new.id)
    returning id into v_personal_wallet_id;

    insert into public.wallet_members (wallet_id, user_id, role)
    values (v_personal_wallet_id, new.id, 'owner')
    on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. RPC untuk membuat Dompet Bersama baru (pembuat otomatis menjadi owner)
create or replace function public.create_shared_wallet(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_wallet_id uuid;
  v_invite_code text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Autentikasi diperlukan';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Nama dompet bersama wajib diisi';
  end if;

  v_invite_code := 'FNK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.wallets (name, is_shared, invite_code, created_by)
  values (trim(p_name), true, v_invite_code, v_user_id)
  returning id into v_wallet_id;

  insert into public.wallet_members (wallet_id, user_id, role)
  values (v_wallet_id, v_user_id, 'owner')
  on conflict (wallet_id, user_id) do nothing;

  return v_wallet_id;
end;
$$;

-- 5. Perbarui RPC join_wallet_by_invite agar case-insensitive dan aman
create or replace function public.join_wallet_by_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_wallet_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Autentikasi diperlukan';
  end if;

  select id into v_wallet_id
  from public.wallets
  where upper(trim(invite_code)) = upper(trim(p_invite_code))
    and is_shared = true
  limit 1;

  if v_wallet_id is null then
    raise exception 'Kode undangan tidak ditemukan';
  end if;

  insert into public.wallet_members (wallet_id, user_id, role)
  values (v_wallet_id, v_user_id, 'editor')
  on conflict (wallet_id, user_id) do nothing;

  return v_wallet_id;
end;
$$;

-- 6. Storage Bucket `avatars` dan Kebijakan RLS Storage (SELECT + INSERT + UPDATE + DELETE)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "Avatar publik dapat dibaca semua orang" on storage.objects;
create policy "Avatar publik dapat dibaca semua orang"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "Pengguna terautentikasi dapat mengunggah avatar sendiri" on storage.objects;
create policy "Pengguna terautentikasi dapat mengunggah avatar sendiri"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Pengguna dapat memperbarui avatar sendiri" on storage.objects;
create policy "Pengguna dapat memperbarui avatar sendiri"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Pengguna dapat menghapus avatar sendiri" on storage.objects;
create policy "Pengguna dapat menghapus avatar sendiri"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- 7. Publikasikan perubahan wallet_members ke Supabase Realtime agar perubahan role langsung sinkron
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'wallet_members'
  ) then
    alter publication supabase_realtime add table public.wallet_members;
  end if;
end $$;

-- 8. Hardening hak eksekusi fungsi RPC & Index FK untuk performa
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.join_wallet_by_invite(text) from public, anon;
grant execute on function public.join_wallet_by_invite(text) to authenticated;
revoke all on function public.create_shared_wallet(text) from public, anon;
grant execute on function public.create_shared_wallet(text) to authenticated;

create index if not exists idx_transactions_created_by on public.transactions (created_by);
create index if not exists idx_wallet_members_user_id on public.wallet_members (user_id);
create index if not exists idx_wallets_created_by on public.wallets (created_by);
