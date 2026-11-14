-- ============================================================================
--  Volkov Family App — схема синхронизации для Supabase
--  Запустить целиком в Supabase → SQL Editor → New query → Run.
--  Повторный запуск безопасен (idempotent).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Таблица данных семьи.
--
-- Одна таблица для ВСЕХ сущностей приложения (tasks, purchases, notes, …):
-- реальные поля лежат в payload (jsonb). Благодаря этому добавление новой
-- колонки в приложении не требует менять схему в облаке.
--
-- owner = auth.uid() — владелец строки (ваш общий аккаунт семьи).
-- RLS ниже гарантирует, что чужая семья не прочитает эти данные,
-- даже если у неё есть anon-ключ.
-- ---------------------------------------------------------------------------
create table if not exists public.family_data (
  sync_id    text        primary key,
  table_name text        not null,
  owner      uuid        not null default auth.uid(),
  updated_at bigint      not null default 0,
  deleted    boolean     not null default false,
  payload    jsonb       not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.family_data is
  'Семейные данные приложения: одна строка = одна запись локальной SQLite-таблицы';

-- Индексы для выборки по семье и по таблице
create index if not exists family_data_owner_idx
  on public.family_data (owner, table_name);

create index if not exists family_data_updated_idx
  on public.family_data (owner, updated_at);

-- ---------------------------------------------------------------------------
-- 2. Row Level Security — ГОЛОВНОЙ элемент защиты.
-- Без этих политик любой, у кого есть anon-ключ из APK, прочитал бы все данные.
-- ---------------------------------------------------------------------------
alter table public.family_data enable row level security;

drop policy if exists "family_data_select_own" on public.family_data;
create policy "family_data_select_own"
  on public.family_data
  for select
  using (owner = auth.uid());

drop policy if exists "family_data_insert_own" on public.family_data;
create policy "family_data_insert_own"
  on public.family_data
  for insert
  with check (owner = auth.uid());

drop policy if exists "family_data_update_own" on public.family_data;
create policy "family_data_update_own"
  on public.family_data
  for update
  using (owner = auth.uid())
  with check (owner = auth.uid());

drop policy if exists "family_data_delete_own" on public.family_data;
create policy "family_data_delete_own"
  on public.family_data
  for delete
  using (owner = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. Триггер: любой UPDATE поднимает updated_at (на случай ручных правок).
-- Приложение всегда присылает updated_at явно, поэтому триггер не мешает.
-- ---------------------------------------------------------------------------
create or replace function public.family_data_touch()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at := (extract(epoch from now()) * 1000)::bigint;
  end if;
  return new;
end;
$$;

drop trigger if exists family_data_touch_trigger on public.family_data;
create trigger family_data_touch_trigger
  before update on public.family_data
  for each row
  execute function public.family_data_touch();

-- ---------------------------------------------------------------------------
-- 4. Проверка, что всё создалось
-- ---------------------------------------------------------------------------
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where tablename = 'family_data'
order by policyname;
