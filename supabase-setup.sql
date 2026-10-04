-- 筋トレ手帳：Supabase セットアップ用 SQL
-- Supabase の管理画面 → SQL Editor に全部貼り付けて「Run」を押すだけです。
-- 何度実行しても壊れないように書いてあります。

-- 1) 記録本体：1ユーザーにつき1行。アプリのデータ全体を JSON で保存します。
create table if not exists public.app_data (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb       not null,
  rev        integer     not null default 1,      -- 更新のたびに +1（端末間の上書き事故を検知するため）
  updated_at timestamptz not null default now()
);

-- 2) 行レベルセキュリティ：ログインした本人の行だけ読み書きできる
alter table public.app_data enable row level security;

drop policy if exists "app_data select own" on public.app_data;
drop policy if exists "app_data insert own" on public.app_data;
drop policy if exists "app_data update own" on public.app_data;

create policy "app_data select own" on public.app_data
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "app_data insert own" on public.app_data
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "app_data update own" on public.app_data
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- delete のポリシーは作らない（アプリからは行ごと消せない）

-- 3) 自動スナップショット：1日1回、その日最初に更新される直前の状態を保存（30日分）
--    アプリからは見えません。誤って消した時は管理画面から復元できます（README参照）。
create table if not exists public.app_data_history (
  user_id  uuid        not null,
  day      date        not null,
  data     jsonb       not null,
  rev      integer     not null,
  saved_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.app_data_history enable row level security;  -- ポリシー無し＝API からは一切アクセス不可

create or replace function public.app_data_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Asia/Tokyo')::date;
begin
  new.updated_at := now();
  insert into public.app_data_history (user_id, day, data, rev)
    values (old.user_id, today, old.data, old.rev)
    on conflict (user_id, day) do nothing;
  delete from public.app_data_history
    where user_id = old.user_id and day < today - 30;
  return new;
end;
$$;

revoke all on function public.app_data_before_update() from public, anon, authenticated;

drop trigger if exists app_data_before_update on public.app_data;
create trigger app_data_before_update
  before update on public.app_data
  for each row execute function public.app_data_before_update();
