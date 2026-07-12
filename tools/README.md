# Bulk import — local BAC archive → Supabase

`import_archive.py` uploads the `علوم تجريبية` content from your local archive
into Supabase (Storage + `exams` table), so the app can sync and display it.

- **171 exam entries, 343 PDFs, ~312 MB** (as of the current archive).
- Maps archive subjects to the app's 9 subjects; **Amazigh is skipped** (not one
  of the 9). File mapping: `الاختبار.pdf`→الموضوع, `التصحيح.pdf`→الحل,
  `التصحيح_المفصل.pdf`→الحل النموذجي.
- Uses the **anon key + admin login** (no service_role). Idempotent (safe to
  re-run: it overwrites files and upserts rows). Stdlib only.

## Prerequisite: a live Supabase project
1. Create a project at supabase.com.
2. SQL Editor → run `supabase/migration.sql`.
3. Authentication → Users → Add user → your admin email + password (Auto Confirm).

## Run (PowerShell, from the repo root)
```powershell
$env:SUPABASE_URL="https://YOUR-REF.supabase.co"
$env:SUPABASE_ANON_KEY="eyJ..."           # Settings → API → anon public
$env:ADMIN_EMAIL="you@example.com"
$env:ADMIN_PASSWORD="your-admin-password"
python tools/import_archive.py
```
Plan without uploading: `python tools/import_archive.py --dry-run`
