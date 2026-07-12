-- =============================================================================
-- أرشيف البكالوريا — Supabase migration (schema + storage + RLS)
-- Stream scope: علوم تجريبية only (kept as a column for future streams).
--
-- HOW TO RUN:
--   Supabase Dashboard → SQL Editor → New query → paste this whole file → Run.
--   Safe to re-run (idempotent).
--
-- SECURITY MODEL:
--   The anon key ships inside the public APK, so it is NOT a secret.
--   Read is open to everyone; all writes are locked behind Auth via RLS.
--   Never put the service_role key in either client.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. exams table  (one row per year + subject; up to 3 PDFs each)
--      sujet_url      = الموضوع
--      solution_url   = الحل
--      correction_url = الحل النموذجي
--      file_size_bytes = total bytes of the files stored for this row
-- -----------------------------------------------------------------------------
create table if not exists public.exams (
  id              uuid        primary key default gen_random_uuid(),
  year            text        not null,
  stream          text        not null default 'علوم تجريبية',
  subject         text        not null,
  sujet_url       text,
  solution_url    text,
  correction_url  text,
  file_size_bytes bigint      default 0,
  created_at      timestamptz default now()
);

-- One archive entry per (year, stream, subject) so the dashboard can UPSERT
-- when you add a missing file to an existing entry instead of duplicating it.
create unique index if not exists exams_year_stream_subject_key
  on public.exams (year, stream, subject);

-- Home grid orders by newest year; delta-sync scans by created_at.
create index if not exists exams_created_at_idx on public.exams (created_at);

-- -----------------------------------------------------------------------------
-- 2. Row Level Security on public.exams
--      SELECT           -> everyone (anon + authenticated): the student app
--      INSERT/UPDATE/DELETE -> authenticated only: the admin dashboard
-- -----------------------------------------------------------------------------
alter table public.exams enable row level security;

drop policy if exists "exams_public_read" on public.exams;
drop policy if exists "exams_auth_insert" on public.exams;
drop policy if exists "exams_auth_update" on public.exams;
drop policy if exists "exams_auth_delete" on public.exams;

create policy "exams_public_read"
  on public.exams for select
  to anon, authenticated
  using (true);

create policy "exams_auth_insert"
  on public.exams for insert
  to authenticated
  with check (true);

create policy "exams_auth_update"
  on public.exams for update
  to authenticated
  using (true)
  with check (true);

create policy "exams_auth_delete"
  on public.exams for delete
  to authenticated
  using (true);

-- -----------------------------------------------------------------------------
-- 3. Storage bucket 'bac-files'  (PUBLIC — served via plain CDN URLs)
--      Object key layout (ENGLISH slugs to avoid Arabic URL-encoding issues):
--         {year}/sciences/{subject-slug}/sujet.pdf
--         {year}/sciences/{subject-slug}/solution.pdf
--         {year}/sciences/{subject-slug}/correction.pdf
--      e.g.  2024/sciences/maths/sujet.pdf
--
--      subject-slug mapping (Arabic label in DB  ->  slug in path):
--         رياضيات        -> maths
--         فيزياء         -> physique
--         علوم طبيعية    -> svt
--         عربية          -> arabe
--         فرنسية         -> francais
--         إنجليزية       -> anglais
--         فلسفة          -> philo
--         تاريخ وجغرافيا -> histoire-geo
--         تربية إسلامية  -> islamique
--         (other)        -> autre
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bac-files', 'bac-files', true, 52428800, array['application/pdf'])  -- 50 MB/file
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Storage RLS: public read, authenticated write.
drop policy if exists "bacfiles_public_read" on storage.objects;
drop policy if exists "bacfiles_auth_insert" on storage.objects;
drop policy if exists "bacfiles_auth_update" on storage.objects;
drop policy if exists "bacfiles_auth_delete" on storage.objects;

create policy "bacfiles_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'bac-files');

create policy "bacfiles_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'bac-files');

create policy "bacfiles_auth_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'bac-files')
  with check (bucket_id = 'bac-files');

create policy "bacfiles_auth_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'bac-files');

-- =============================================================================
-- Done. Then create your single admin account in the dashboard
-- (Authentication → Users → Add user), and move on to Step 2.
-- =============================================================================
