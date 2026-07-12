# لوحة تحكم أرشيف البكالوريا — Admin Dashboard

Plain HTML/CSS/JS + Supabase JS client (loaded from CDN as an ES module).

## Setup

1. Open `config.js` and paste your **Project URL** and **anon public key**
   (Supabase → Settings → API). The anon key is public by design — RLS controls access.
2. Serve the folder over HTTP (ES modules do **not** work from `file://`):

   ```bash
   # from the admin/ folder — any static server works:
   python -m http.server 5173
   ```

   Then open http://localhost:5173

   (Or use the VS Code "Live Server" extension.)

3. Log in with the admin account you created in Supabase
   (Authentication → Users → Add user).

## Files

| File                | Purpose                                             |
| ------------------- | --------------------------------------------------- |
| `index.html`        | Login view + add-content form shell                 |
| `styles.css`        | Design system (deep blue / RTL / Material-ish)      |
| `config.js`         | **You fill this in** — Project URL + anon key        |
| `constants.js`      | Subjects, English slugs, storage layout (shared)    |
| `supabaseClient.js` | Creates the Supabase client                         |
| `app.js`            | Auth + add-content upload/upsert logic              |

## What Step 2 covers

- Email/password login; everything else is blocked until logged in.
- Add-content form: year + subject dropdown + 3 PDF pickers
  (الموضوع / الحل / الحل النموذجي).
- On submit: uploads each chosen PDF to
  `{year}/sciences/{subject-slug}/…` in the `bac-files` bucket, reads back the
  folder to compute total size + public URLs, then upserts one `exams` row per
  (year, stream, subject). Missing files can be added later to the same entry.

Content management view (search / delete / totals) comes in Step 3.
