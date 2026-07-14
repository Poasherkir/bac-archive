-- =============================================================================
-- Migration 2 — multi-stream support (علوم تجريبية + رياضيات + تقني رياضي)
--
-- Adds `streams text[]`: the set of streams that share one exam entry (and
-- its PDFs). The legacy `stream` column stays as the row's PRIMARY stream so
-- already-installed app versions keep working unchanged:
--   * rows visible to the old app keep stream = 'علوم تجريبية'
--   * new maths/tech rows carry their own primary stream and are invisible
--     to old clients
--
-- Run in the Supabase SQL editor. Idempotent.
-- =============================================================================

alter table public.exams
  add column if not exists streams text[];

update public.exams
  set streams = array[stream]
  where streams is null;

alter table public.exams
  alter column streams set not null;

alter table public.exams
  alter column streams set default array['علوم تجريبية']::text[];

-- Fast "which rows belong to stream X" lookups (app sync query).
create index if not exists exams_streams_gin
  on public.exams using gin (streams);
