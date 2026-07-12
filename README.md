# أرشيف البكالوريا — BAC Archive

**An offline-first archive of Algerian Baccalaureate exam papers for the
علوم تجريبية (Experimental Sciences) stream** — every exam (الموضوع), official
answer (الحل), and model answer (الحل النموذجي) from **2008 to 2026**, organized
by year and subject, readable entirely without internet after a single sync.

The project has three parts sharing one Supabase backend:

| Part | Directory | Audience |
|---|---|---|
| 📱 Flutter Android app | [`app/`](app/) | Students — browse & read PDFs fully offline |
| 🖥️ Web admin dashboard | [`admin/`](admin/) | Owner — upload/manage content, no code needed |
| 🐍 Bulk importer | [`tools/`](tools/) | Owner — one-shot import of a local archive |

Currently serving **171 exam entries / 343 PDFs (~312 MB)** across 19 years and
9 subjects.

---

## Table of contents

- [How it works](#how-it-works)
- [Backend (Supabase)](#backend-supabase)
- [The Flutter app](#the-flutter-app)
  - [Offline-first sync](#offline-first-sync)
  - [Screens](#screens)
  - [Design system](#design-system)
  - [Project structure](#project-structure)
- [The admin dashboard](#the-admin-dashboard)
- [The bulk importer](#the-bulk-importer)
- [Getting started from scratch](#getting-started-from-scratch)
- [Building a release](#building-a-release)
- [Testing](#testing)
- [Operational notes](#operational-notes)

---

## How it works

```
                       ┌─────────────────────────────┐
                       │           SUPABASE          │
                       │                             │
   ┌────────────┐      │  ┌───────────────────────┐  │
   │   Admin    │─auth─┼─▶│ exams table           │  │
   │ dashboard  │ write│  │ (year·stream·subject, │  │
   └────────────┘      │  │  3 file URLs, size)   │  │
                       │  └───────────────────────┘  │
   ┌────────────┐      │  ┌───────────────────────┐  │
   │  Importer  │─────▶│  │ bac-files bucket      │  │
   │ (one-shot) │      │  │ {year}/sciences/{subj}│  │
   └────────────┘      │  │  /sujet|solution|     │  │
                       │  │   correction.pdf      │  │
                       │  └───────────┬───────────┘  │
                       └──────────────┼──────────────┘
                                      │ public read (anon key + RLS)
                                      ▼
                       ┌─────────────────────────────┐
                       │        FLUTTER APP          │
                       │                             │
                       │ 1st launch: full sync ────┐ │
                       │ later: silent delta-sync  │ │
                       │                           ▼ │
                       │   local mirror + manifest   │
                       │   (100% offline browsing)   │
                       └─────────────────────────────┘
```

The core idea: **the app is a mirror, not a client.** After one successful
sync, every screen and every PDF reads from local storage — zero network
calls. The network is only used to *refresh the mirror* when available.

---

## Backend (Supabase)

Everything is defined in [`supabase/migration.sql`](supabase/migration.sql)
(run once in the Supabase SQL editor).

### `exams` table

One row per (year, stream, subject) with up to three PDF URLs:

```sql
create table exams (
  id uuid primary key default gen_random_uuid(),
  year text not null,
  stream text not null default 'علوم تجريبية',
  subject text not null,
  sujet_url text,          -- الموضوع  (exam paper)
  solution_url text,       -- الحل     (official answer)
  correction_url text,     -- الحل النموذجي (model answer)
  file_size_bytes bigint default 0,
  created_at timestamptz default now()
);
```

The `stream` column exists even though only one value is used today — adding a
second stream later is a **data** change, not a schema migration.

### Storage layout

One **public** bucket `bac-files`. Paths use **English slugs** (not Arabic) to
avoid URL-encoding problems:

```
{year}/sciences/{subject-slug}/sujet.pdf
{year}/sciences/{subject-slug}/solution.pdf
{year}/sciences/{subject-slug}/correction.pdf
      e.g. 2024/sciences/maths/sujet.pdf
```

The slug ↔ Arabic label mapping is defined identically in three places and
must stay in sync: `admin/constants.js`, `app/lib/config/app_config.dart`,
`tools/import_archive.py`.

| Slug | Label | | Slug | Label |
|---|---|---|---|---|
| `maths` | رياضيات | | `anglais` | إنجليزية |
| `physique` | فيزياء | | `philo` | فلسفة |
| `svt` | علوم طبيعية | | `histoire-geo` | تاريخ وجغرافيا |
| `arabe` | عربية | | `islamique` | تربية إسلامية |
| `francais` | فرنسية | | | |

### Security model (RLS)

The **anon key ships inside the public APK**, so security cannot rely on key
secrecy. Instead:

- `exams`: `SELECT` for everyone (anon + authenticated); `INSERT/UPDATE/DELETE`
  **only** for authenticated users.
- `bac-files`: public read; upload/delete **only** for authenticated users.
- The only authenticated user is the owner's admin account (email/password via
  Supabase Auth). The `service_role` key is never used in any client.

---

## The Flutter app

**Stack:** Flutter (stable) · Riverpod · go_router · supabase_flutter · pdfx ·
share_plus · connectivity_plus · shared_preferences · google_fonts.

**Android:** `applicationId com.malik.bacsci` · minSdk 24 · targetSdk 36 ·
R8 shrinking · `INTERNET` permission only (plus the non-sensitive
`ACCESS_NETWORK_STATE` from connectivity_plus).

### Offline-first sync

**First launch** — the "تجهيز المحتوى" screen
([`sync_screen.dart`](app/lib/screens/sync_screen.dart) driven by the
[`SyncController`](app/lib/providers/sync_controller.dart) state machine):

1. Fetch the full manifest (`exams` where `stream = 'علوم تجريبية'`).
2. Diff against local disk → list of missing files + total size.
3. On mobile data: warning dialog with the download size —
   **متابعة / انتظار واي فاي**. On Wi-Fi: start silently.
4. Download every PDF with a real progress bar and *X من Y ملف* counter.
   Downloads are **cancel-safe and resumable**: each file streams to a
   `.part` temp file and is renamed only on success
   ([`downloader.dart`](app/lib/services/downloader.dart)), so a killed app
   never leaves a half-file that looks complete.
5. Persist the manifest to `manifest.json`, set the `sync_complete` flag —
   this screen never appears again.

Local files mirror the storage layout exactly, with the path **derived from
the public URL** ([`local_store.dart`](app/lib/services/local_store.dart)) —
the app can never drift from whatever paths the dashboard uploaded to:

```
<app documents>/bac_files/2024/sciences/maths/sujet.pdf
```

**Every later launch:**

- The router boots **straight to Home**; browsing reads only the cached
  manifest + local files.
- If online, a **silent delta-sync**
  ([`delta_sync.dart`](app/lib/providers/delta_sync.dart)) runs once per
  session in the background: fetch manifest → download only new files →
  refresh the UI only if something changed. This is how new uploads reach
  students **without an app update**.
- If offline, the check is skipped entirely — nothing blocks, nothing errors.

### Screens

| Route | Screen | Notes |
|---|---|---|
| `/sync` | Preparing content | First launch only; animated gradient, staggered entrance, live progress |
| `/` | Home | Large header, Material 3 SearchBar (filter years), responsive grid of year cards with per-year accent colors, "الأحدث" badge on the newest year, settings sheet (theme + about) |
| `/year/:year` | Subjects | 9 subject cards with per-subject accent colors; subjects with no content are dimmed ("لم تُضف بعد") |
| `/year/:year/subject/:slug` | Subject | Three buttons — الموضوع / الحل / الحل النموذجي — enabled only when the PDF exists on disk |
| `/viewer` | PDF viewer | pdfx pinch-zoom viewer, floating page pill (prev/next + "صفحة X من Y"), share, fullscreen |

Routing note: subject routes carry the **ASCII slug**, never the Arabic label —
percent-encoded Arabic in paths breaks `Uri.decodeComponent` in release builds.

### Design system

- **Light:** primary `#2563EB`, background `#F8FAFC`, white cards (radius 24,
  soft shadows), text `#0F172A` / `#64748B`.
- **Dark:** background `#0F172A`, cards `#1E293B`, primary `#3B82F6`, off-white
  text — full dark mode with a persisted **system / light / dark** toggle in
  the Home settings sheet.
- **Typography:** [Alexandria](https://fonts.google.com/specimen/Alexandria)
  (Arabic-first) via google_fonts.
- **RTL everywhere**, forced at the `MaterialApp` level.
- Motion: staggered fade/rise entrances, press-scale on cards,
  `easeInOutCubic`, all one-shot animations (no persistent controllers on
  browsing screens).

### Project structure

```
app/lib/
├── config/app_config.dart      # Supabase keys, bucket, stream, subjects, file kinds
├── models/exam.dart            # Exam row model (fromMap/toMap, availableFiles)
├── services/
│   ├── local_store.dart        # local mirror + manifest cache + sync flag
│   ├── downloader.dart         # streaming, resumable, cancel-safe downloads
│   ├── exam_repository.dart    # manifest fetch from Supabase
│   └── sync_service.dart       # diff planner + delta-sync runner
├── providers/
│   ├── providers.dart          # DI wiring (prefs, connectivity, services)
│   ├── sync_controller.dart    # first-launch sync state machine
│   ├── manifest_providers.dart # offline browsing derived state
│   ├── delta_sync.dart         # once-per-session background refresh
│   └── theme_mode.dart         # persisted ThemeMode
├── router/app_router.dart      # go_router, slug-based paths, first-launch gate
├── screens/                    # sync, home, year, subject, pdf_viewer
├── theme/app_theme.dart        # light+dark ColorSchemes, accent maps
├── utils/format.dart           # byte formatting
└── widgets/                    # year_card, subject_card, search bar, breadcrumb,
                                #  entrance animation, empty states
```

---

## The admin dashboard

Plain HTML/CSS/JS + the Supabase JS client — no build step, no framework.

- **Login-gated** (Supabase Auth email/password); nothing renders until a
  session exists.
- **Add content:** pick year + subject (dropdown of the 9 subjects + أخرى) and
  up to three PDFs. On submit it uploads to the correct storage path
  (overwrite-safe), reads the folder back to compute real sizes + public URLs,
  and **upserts** one row per (year, stream, subject) — so missing files can
  be added later to the same entry.
- **Manage:** searchable table (year, subject, ✓/— per file, size), yellow
  "ملفات ناقصة" flag for incomplete entries, running total archive size, and
  delete (removes storage files + row).

Run it locally:

```bash
cd admin
python serve.py          # http://localhost:5173
```

> `serve.py` exists because plain `python -m http.server` on Windows serves
> `.js` with a MIME type browsers reject for ES modules.

---

## The bulk importer

[`tools/import_archive.py`](tools/import_archive.py) — stdlib-only Python that
walks a local archive laid out as
`{year}/علوم تجريبية/{subject}/الاختبار.pdf|التصحيح.pdf|التصحيح_المفصل.pdf`,
maps subjects/files to the app's slugs and columns, uploads everything to the
bucket and upserts the rows.

- **Idempotent & resumable** — skips files already in storage (HEAD check),
  retries transient network failures, safe to re-run anytime.
- Auth: either the service key (`SUPABASE_SERVICE_KEY`) or admin
  email/password with the anon key. See [`tools/README.md`](tools/README.md).
- `--dry-run` prints the plan without any network calls.

---

## Getting started from scratch

1. **Supabase** — create a project, run `supabase/migration.sql` in the SQL
   editor, add your admin user (Authentication → Users → Add user, Auto
   Confirm).
2. **Keys** — put the project URL + anon key into `admin/config.js` and
   `app/lib/config/app_config.dart` (or pass `--dart-define=SUPABASE_URL=...
   --dart-define=SUPABASE_ANON_KEY=...` at build time).
3. **Content** — either upload through the dashboard, or bulk-import a local
   archive with the importer.
4. **App** — `cd app && flutter pub get && flutter run`.

---

## Building a release

Signing is wired via `app/android/key.properties` + a keystore at
`app/android/app/upload-keystore.jks` — **both intentionally git-ignored**.
Generate your own:

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

then create `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

Build the Play Store bundle:

```bash
cd app
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Versioning lives in `pubspec.yaml` (`version: 1.0.0+1` →
versionName `1.0.0`, versionCode `1`; the code must increase every upload).
Full checklist (Play Console steps, privacy policy hosting, listing text):
[`app/RELEASE.md`](app/RELEASE.md) · [`store-listing-ar.md`](store-listing-ar.md)
· [`privacy-policy/`](privacy-policy/).

> ⚠️ **Back up the keystore.** Losing it means you can never update the
> published app.

---

## Testing

```bash
cd app
flutter analyze
flutter test
```

Covers: the exam model, URL→local-path mirroring, sync-flag persistence, the
delta-sync loop end-to-end (with fake repo/downloader against a temp dir), and
widget tests for the Home and Subject screens (grid building, search
filtering, empty states, latest-year badge).

---

## Operational notes

- **Egress budget:** each fresh install downloads the full archive
  (~312 MB). Supabase's free tier includes 5 GB egress/month ≈ 16 full
  first-syncs. Before a wide public launch, either upgrade the plan or switch
  the app to lazy per-file download (fetch on first open, then cache).
- **Model answers are sparse by nature:** almost all entries have الموضوع +
  الحل; only a couple of years shipped a separate detailed correction, so the
  third button legitimately shows "غير متوفر" for most subjects.
- **Amazigh (اللغة الأمازيغية)** exists in the source archive but is not one of
  the app's 9 subjects, so the importer skips it deliberately.
- **The anon key in this repo is public by design** — all write access is
  gated by Auth + RLS, not key secrecy. The service key and keystore are the
  actual secrets and are never committed.
