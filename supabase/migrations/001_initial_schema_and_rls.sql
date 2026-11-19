-- =============================================================================
-- Finku: Budget & Money Manager - Initial Schema & Row Level Security (RLS)
-- Sesuai spesifikasi Bab 4 GEMINI.md
-- =============================================================================

-- 0. Extensions
create extension if not exists pgcrypto;

-- 1. Enum untuk Peran Anggota Mode Bersama & Sumber Pencatatan
create type public.wallet_role as enum ('owner', 'editor', 'viewer');
create type public.tx_source as enum ('manual', 'ocr', 'ai_chat');

-- 2. Tabel Profil Pengguna (untuk atribusi nama anggota di Dompet Bersama)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  avatar_initials text not null default 'FK',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Tabel Dompet (Mendukung Dompet Pribadi & Dompet Bersama / Shared Wallet)
create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_shared boolean not null default false,
  invite_code text unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. Tabel Anggota Dompet Bersama (RBAC: Owner, Editor, Viewer)
create table public.wallet_members (
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.wallet_role not null default 'viewer',
  joined_at timestamptz not null default now(),
  primary key (wallet_id, user_id)
);

-- 5. Tabel Anggaran Bulanan (Monthly Budgets per Kategori)
create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  category text not null,
  month_period text not null, -- Format: 'YYYY-MM' (contoh: '2026-11')
  limit_amount bigint not null check (limit_amount > 0),
  updated_at timestamptz not null default now(),
  unique (wallet_id, category, month_period)
);

-- 6. Tabel Transaksi (Mendukung Deduplikasi Offline & Last-Write-Wins)
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  client_tx_id text not null unique, -- UUID lokal perangkat untuk cegah duplikasi saat Offline Sync (TC-SYNC-03)
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  merchant_name text not null,
  category text not null,
  amount bigint not null check (amount > 0), -- Disimpan dalam Rupiah bulat (integer)
  source public.tx_source not null default 'manual',
  receipt_url text,
  tx_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now() -- Acuan waktu Last-Write-Wins (FR-SYNC-04)
);

-- Index untuk performa agregasi grafik & filter (FR-VIS & FR-SYNC)
create index idx_transactions_wallet_date on public.transactions (wallet_id, tx_date desc);
create index idx_transactions_wallet_category on public.transactions (wallet_id, category);
create index idx_budgets_wallet_period on public.budgets (wallet_id, month_period);

-- 7. Helper Functions SECURITY DEFINER untuk mencegah rekursi RLS pada wallet_members
create or replace function public.is_wallet_member(target_wallet_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.wallet_members wm
    where wm.wallet_id = target_wallet_id
      and wm.user_id = auth.uid()
  );
$$;

create or replace function public.can_edit_wallet(target_wallet_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.wallet_members wm
    where wm.wallet_id = target_wallet_id
      and wm.user_id = auth.uid()
      and wm.role in ('owner', 'editor')
  );
$$;

create or replace function public.is_wallet_owner(target_wallet_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.wallet_members wm
    where wm.wallet_id = target_wallet_id
      and wm.user_id = auth.uid()
      and wm.role = 'owner'
  );
$$;

-- Trigger otomatis untuk membuat profil & dompet pribadi saat user baru daftar
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_initials text;
  v_personal_wallet_id uuid;
begin
  v_name := coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1));
  v_initials := upper(left(regexp_replace(v_name, '[^a-zA-Z]', '', 'g'), 2));
  if length(v_initials) = 0 then
    v_initials := 'FK';
  end if;

  insert into public.profiles (id, email, full_name, avatar_initials)
  values (new.id, coalesce(new.email, ''), v_name, v_initials)
  on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name,
        updated_at = now();

  -- Buat dompet pribadi default jika user belum memiliki dompet pribadi
  if not exists (
    select 1 from public.wallets w
    where w.created_by = new.id and w.is_shared = false
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

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 8. Aktifkan Row Level Security (RLS) pada semua tabel di skema public
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_members enable row level security;
alter table public.budgets enable row level security;
alter table public.transactions enable row level security;

-- Kebijakan RLS Profiles
create policy "Pengguna terautentikasi dapat melihat profil anggota"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Pengguna hanya dapat mengubah profil sendiri"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Kebijakan RLS Wallets
create policy "Anggota dapat melihat dompet mereka"
  on public.wallets for select
  to authenticated
  using (public.is_wallet_member(id) or created_by = auth.uid());

create policy "Pengguna terautentikasi dapat membuat dompet"
  on public.wallets for insert
  to authenticated
  with check (created_by = auth.uid());

create policy "Hanya owner dan editor dapat memperbarui dompet"
  on public.wallets for update
  to authenticated
  using (public.can_edit_wallet(id))
  with check (public.can_edit_wallet(id));

create policy "Hanya owner dapat menghapus dompet"
  on public.wallets for delete
  to authenticated
  using (public.is_wallet_owner(id));

-- Kebijakan RLS Wallet Members
create policy "Anggota dapat melihat daftar anggota dompet"
  on public.wallet_members for select
  to authenticated
  using (public.is_wallet_member(wallet_id));

create policy "Owner atau pembuat dompet dapat menambah anggota"
  on public.wallet_members for insert
  to authenticated
  with check (
    public.is_wallet_owner(wallet_id)
    or exists (
      select 1 from public.wallets w
      where w.id = wallet_id and w.created_by = auth.uid()
    )
  );

create policy "Hanya owner yang dapat mengubah atau menghapus anggota"
  on public.wallet_members for update
  to authenticated
  using (public.is_wallet_owner(wallet_id))
  with check (public.is_wallet_owner(wallet_id));

create policy "Hanya owner yang dapat mengeluarkan anggota"
  on public.wallet_members for delete
  to authenticated
  using (public.is_wallet_owner(wallet_id));

-- RPC aman untuk bergabung via kode undangan dompet bersama
create or replace function public.join_wallet_by_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
begin
  select id into v_wallet_id
  from public.wallets
  where invite_code = p_invite_code and is_shared = true
  limit 1;

  if v_wallet_id is null then
    raise exception 'Kode undangan tidak ditemukan';
  end if;

  insert into public.wallet_members (wallet_id, user_id, role)
  values (v_wallet_id, auth.uid(), 'editor')
  on conflict (wallet_id, user_id) do nothing;

  return v_wallet_id;
end;
$$;

-- Kebijakan RLS Budgets
create policy "Anggota dapat melihat anggaran dompet"
  on public.budgets for select
  to authenticated
  using (public.is_wallet_member(wallet_id));

create policy "Hanya owner dan editor dapat memodifikasi anggaran"
  on public.budgets for all
  to authenticated
  using (public.can_edit_wallet(wallet_id))
  with check (public.can_edit_wallet(wallet_id));

-- Kebijakan RLS Transaksi: Semua anggota (owner, editor, viewer) dapat membaca (SELECT)
create policy "Anggota dapat melihat transaksi dompet"
  on public.transactions for select
  to authenticated
  using (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
    )
  );

-- Kebijakan RLS Transaksi: HANYA 'owner' dan 'editor' yang dapat menambah/mengubah/menghapus (TC-SYNC-04)
create policy "Hanya owner dan editor yang dapat memodifikasi transaksi"
  on public.transactions for all
  to authenticated
  using (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
        and wm.role in ('owner', 'editor')
    )
  )
  with check (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
        and wm.role in ('owner', 'editor')
    )
  );

-- 9. Aktifkan Replica Identity Full & Publikasi Supabase Realtime (< 1.5 detik)
alter table public.transactions replica identity full;
alter table public.budgets replica identity full;
alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.budgets;
