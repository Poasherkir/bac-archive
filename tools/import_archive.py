#!/usr/bin/env python3
"""
Bulk-import the local BAC archive into Supabase (Storage + exams table).

Scope: the 'علوم تجريبية' stream only. Walks:
    {ARCHIVE_ROOT}/{year}/علوم تجريبية/{subject}/{الاختبار|التصحيح|التصحيح_المفصل}.pdf
maps each subject to one of the app's 9 canonical subjects, uploads the PDFs to
the public 'bac-files' bucket at {year}/sciences/{slug}/{sujet|solution|correction}.pdf,
and upserts one row per (year, subject) into the exams table.

Auth: logs in as the admin (email/password) using the ANON key — no service_role.
Only the Python standard library is used (no pip installs).

Usage (PowerShell):
    $env:SUPABASE_URL="https://xxxx.supabase.co"
    $env:SUPABASE_ANON_KEY="eyJ..."
    $env:ADMIN_EMAIL="you@example.com"
    $env:ADMIN_PASSWORD="..."
    python tools/import_archive.py
Options:
    --dry-run     plan only, no network calls
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

STREAM = "علوم تجريبية"
BUCKET = "bac-files"

ARCHIVE_ROOT = os.environ.get(
    "ARCHIVE_ROOT", r"C:\Users\n\Desktop\بكالوريات\bac_archive"
)

# archive subject folder -> (canonical app subject label, english slug)
SUBJECTS = {
    "الرياضيات": ("رياضيات", "maths"),
    "العلوم الفيزيائية": ("فيزياء", "physique"),
    "الفيزياء": ("فيزياء", "physique"),
    "علوم الطبيعة و الحياة": ("علوم طبيعية", "svt"),
    "علوم الطبيعة والحياة": ("علوم طبيعية", "svt"),
    "اللغة العربية و آدابها": ("عربية", "arabe"),
    "اللغة العربية وآدابها": ("عربية", "arabe"),
    "Français": ("فرنسية", "francais"),
    "English": ("إنجليزية", "anglais"),
    "الفلسفة": ("فلسفة", "philo"),
    "الإجتماعيات": ("تاريخ وجغرافيا", "histoire-geo"),
    "التاريخ والجغرافيا": ("تاريخ وجغرافيا", "histoire-geo"),
    "العلوم الإسلامية": ("تربية إسلامية", "islamique"),
    # Amazigh (اللغة الأمازيغية / الأمازيغية) is intentionally not mapped -> skipped.
}

# archive file name -> (kind, storage filename, exams url column). Order matters.
FILES = [
    ("الاختبار.pdf", "sujet.pdf", "sujet_url"),
    ("التصحيح.pdf", "solution.pdf", "solution_url"),
    ("التصحيح_المفصل.pdf", "correction.pdf", "correction_url"),
]

DRY_RUN = "--dry-run" in sys.argv


def die(msg):
    print("ERROR:", msg)
    sys.exit(1)


def login(url, anon, email, password):
    body = json.dumps({"email": email, "password": password}).encode()
    req = urllib.request.Request(
        f"{url}/auth/v1/token?grant_type=password", data=body, method="POST"
    )
    req.add_header("apikey", anon)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            token = json.load(r)["access_token"]
            print("Logged in OK.")
            return token
    except urllib.error.HTTPError as e:
        die(f"login failed ({e.code}): {e.read().decode(errors='replace')}")


def _send(req, retries=5):
    """Send a request with retries on timeouts / 5xx / transient network errors."""
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code >= 500 and attempt < retries - 1:
                time.sleep(2 * (attempt + 1))
                continue
            raise
        except (urllib.error.URLError, TimeoutError, OSError):
            if attempt < retries - 1:
                time.sleep(2 * (attempt + 1))
                continue
            raise


def object_exists(url, object_path):
    """HEAD the public URL (bucket is public) — True if already uploaded."""
    req = urllib.request.Request(
        f"{url}/storage/v1/object/public/{BUCKET}/{object_path}", method="HEAD"
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status == 200
    except Exception:
        return False


def upload_file(url, apikey, token, object_path, local_path):
    with open(local_path, "rb") as f:
        data = f.read()
    req = urllib.request.Request(
        f"{url}/storage/v1/object/{BUCKET}/{object_path}", data=data, method="POST"
    )
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("apikey", apikey)
    req.add_header("Content-Type", "application/pdf")
    req.add_header("x-upsert", "true")  # overwrite if the script is re-run
    try:
        _send(req)
    except urllib.error.HTTPError as e:
        die(f"upload {object_path} failed ({e.code}): {e.read().decode(errors='replace')}")


def upsert_row(url, apikey, token, row):
    body = json.dumps(row).encode()
    req = urllib.request.Request(
        f"{url}/rest/v1/exams?on_conflict=year,stream,subject", data=body, method="POST"
    )
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("apikey", apikey)
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "resolution=merge-duplicates,return=minimal")
    try:
        _send(req)
    except urllib.error.HTTPError as e:
        die(f"upsert row failed ({e.code}): {e.read().decode(errors='replace')}")


def build_plan():
    """Return list of (year, subject_label, slug, {src_filename: local_path})."""
    entries = []
    for year in sorted(os.listdir(ARCHIVE_ROOT)):
        sci = os.path.join(ARCHIVE_ROOT, year, STREAM)
        if not os.path.isdir(sci):
            continue
        for subj in sorted(os.listdir(sci)):
            sp = os.path.join(sci, subj)
            if not os.path.isdir(sp):
                continue
            mapping = SUBJECTS.get(subj)
            if not mapping:
                print(f"  skip (unmapped subject): {year}/{subj!r}")
                continue
            label, slug = mapping
            valid_names = {src for src, _, _ in FILES}
            found = {
                fn: os.path.join(sp, fn)
                for fn in os.listdir(sp)
                if fn in valid_names
            }
            if found:
                entries.append((year, label, slug, found))
    return entries


def main():
    if not os.path.isdir(ARCHIVE_ROOT):
        die(f"archive not found: {ARCHIVE_ROOT}")

    entries = build_plan()
    total_files = sum(len(f) for *_, f in entries)
    print(f"Planned: {len(entries)} exam rows, {total_files} files.")

    if DRY_RUN:
        print("Dry run — no network calls made.")
        return

    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    service = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if service:
        # Service key bypasses RLS/auth — no admin login needed.
        apikey = token = service
        print("Using service key (no login needed).")
    else:
        anon = os.environ.get("SUPABASE_ANON_KEY", "")
        email = os.environ.get("ADMIN_EMAIL", "")
        password = os.environ.get("ADMIN_PASSWORD", "")
        if not all([url, anon, email, password]):
            die("set SUPABASE_SERVICE_KEY, or SUPABASE_ANON_KEY + ADMIN_EMAIL + ADMIN_PASSWORD")
        apikey = anon
        token = login(url, anon, email, password)

    for i, (year, label, slug, found) in enumerate(entries, 1):
        folder = f"{year}/sciences/{slug}"
        row = {"year": year, "stream": STREAM, "subject": label, "file_size_bytes": 0}
        size = 0
        uploaded = 0
        for src_name, storage_name, url_col in FILES:
            local_path = found.get(src_name)
            if not local_path:
                continue
            object_path = f"{folder}/{storage_name}"
            size += os.path.getsize(local_path)
            if not object_exists(url, object_path):  # resume: skip existing
                upload_file(url, apikey, token, object_path, local_path)
                uploaded += 1
            row[url_col] = f"{url}/storage/v1/object/public/{BUCKET}/{object_path}"
        row["file_size_bytes"] = size
        upsert_row(url, apikey, token, row)
        tag = f"+{uploaded}" if uploaded else "skip"
        print(f"[{i}/{len(entries)}] {year}/{slug}  ({size // 1024} KB, {tag})")

    print(f"\nDone. Imported {len(entries)} exam rows.")


if __name__ == "__main__":
    main()
