#!/usr/bin/env python3
"""
Multi-stream import: extend the archive with رياضيات and تقني رياضي,
deduplicating shared PDFs by CONTENT HASH (per year), never by assumption.

For every (year, canonical subject):
  1. Hash الاختبار.pdf in each stream's folder.
  2. Streams with identical hashes form one group = ONE exam row + ONE set
     of stored PDFs, with `streams = [group...]`.
  3. Groups containing علوم تجريبية reuse the already-uploaded sciences
     files (hash-verified identical): the existing row is PATCHed with the
     widened `streams` array — zero new storage.
  4. Groups without sciences upload files once to
     {year}/{group-slug}/{subject-slug}/... and insert a new row whose
     legacy `stream` = the group's first stream (invisible to old clients).

Idempotent: PATCHes repeat harmlessly, uploads use x-upsert, inserts use
on_conflict=year,stream,subject.

Usage (PowerShell):
    $env:SUPABASE_URL="https://xxxx.supabase.co"
    $env:SUPABASE_SERVICE_KEY="sb_secret_..."
    python tools/import_streams.py            # real run
    python tools/import_streams.py --dry-run  # plan only
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.environ.get("ARCHIVE_ROOT", r"C:\Users\n\Desktop\بكالوريات\bac_archive")
BUCKET = "bac-files"
DRY = "--dry-run" in sys.argv

SCI = "علوم تجريبية"
MATH = "رياضيات"
TM = "تقني رياضي"
STREAMS = [SCI, MATH, TM]
STREAM_PATH = {SCI: "sciences", MATH: "math", TM: "tm"}

# Archive folder name -> canonical APP subject label (must match app config).
CANON = {
    "English": "إنجليزية",
    "Français": "فرنسية",
    "الرياضيات": "رياضيات",
    "العلوم الإسلامية": "تربية إسلامية",
    "الفلسفة": "فلسفة",
    "الإجتماعيات": "تاريخ وجغرافيا",
    "التاريخ والجغرافيا": "تاريخ وجغرافيا",
    "العلوم الفيزيائية": "فيزياء",
    "الفيزياء": "فيزياء",
    "اللغة العربية و آدابها": "عربية",
    "اللغة العربية وآدابها": "عربية",
    "علوم الطبيعة و الحياة": "علوم طبيعية",
    "علوم الطبيعة والحياة": "علوم طبيعية",
    "التكنولوجيا": "تكنولوجيا",
    # Amazigh intentionally unmapped -> skipped (not one of the app subjects).
}

SLUG = {
    "رياضيات": "maths",
    "فيزياء": "physique",
    "علوم طبيعية": "svt",
    "عربية": "arabe",
    "فرنسية": "francais",
    "إنجليزية": "anglais",
    "فلسفة": "philo",
    "تاريخ وجغرافيا": "histoire-geo",
    "تربية إسلامية": "islamique",
    "تكنولوجيا": "techno",
}

FILES = [  # (archive name, storage name, exams column)
    ("الاختبار.pdf", "sujet.pdf", "sujet_url"),
    ("التصحيح.pdf", "solution.pdf", "solution_url"),
    ("التصحيح_المفصل.pdf", "correction.pdf", "correction_url"),
]


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _send(req, retries=5):
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


class Client:
    def __init__(self):
        self.url = os.environ.get("SUPABASE_URL", "").rstrip("/")
        self.key = os.environ.get("SUPABASE_SERVICE_KEY", "")
        if not DRY and not (self.url and self.key):
            print("ERROR: set SUPABASE_URL and SUPABASE_SERVICE_KEY")
            sys.exit(1)

    def _headers(self, extra=None):
        h = {"apikey": self.key, "Authorization": f"Bearer {self.key}"}
        h.update(extra or {})
        return h

    def object_exists(self, object_path):
        req = urllib.request.Request(
            f"{self.url}/storage/v1/object/public/{BUCKET}/{object_path}",
            method="HEAD",
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status == 200
        except Exception:
            return False

    def upload(self, object_path, local_path):
        with open(local_path, "rb") as f:
            data = f.read()
        req = urllib.request.Request(
            f"{self.url}/storage/v1/object/{BUCKET}/{object_path}",
            data=data,
            method="POST",
            headers=self._headers(
                {"Content-Type": "application/pdf", "x-upsert": "true"}
            ),
        )
        _send(req)

    def patch_streams(self, year, subject, streams):
        body = json.dumps({"streams": streams}).encode()
        q = urllib.parse.urlencode(
            {"year": f"eq.{year}", "subject": f"eq.{subject}",
             "stream": f"eq.{SCI}"}
        )
        req = urllib.request.Request(
            f"{self.url}/rest/v1/exams?{q}", data=body, method="PATCH",
            headers=self._headers(
                {"Content-Type": "application/json", "Prefer": "return=minimal"}
            ),
        )
        _send(req)

    def upsert(self, row):
        body = json.dumps(row).encode()
        req = urllib.request.Request(
            f"{self.url}/rest/v1/exams?on_conflict=year,stream,subject",
            data=body,
            method="POST",
            headers=self._headers({
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates,return=minimal",
            }),
        )
        _send(req)


import urllib.parse  # noqa: E402  (used by Client.patch_streams)


def build_plan():
    """Yield (year, subject, group_streams, source_dir) actions."""
    years = sorted(
        d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d))
    )
    plan = []
    for year in years:
        # canonical subject -> {stream: (folder_path, exam_hash)}
        per = {}
        for stream in STREAMS:
            sp = os.path.join(ROOT, year, stream)
            if not os.path.isdir(sp):
                continue
            for folder in os.listdir(sp):
                canon = CANON.get(folder)
                if canon is None:
                    continue
                fp = os.path.join(sp, folder)
                exam = os.path.join(fp, "الاختبار.pdf")
                if os.path.isfile(exam):
                    per.setdefault(canon, {})[stream] = (fp, md5(exam))
        for canon, by_stream in per.items():
            groups = {}
            for stream, (fp, h) in by_stream.items():
                groups.setdefault(h, []).append(stream)
            for h, group in groups.items():
                group.sort(key=STREAMS.index)
                # Source folder: the stream in the group with the most files.
                best = max(
                    group,
                    key=lambda st: sum(
                        os.path.isfile(os.path.join(by_stream[st][0], a))
                        for a, _, _ in FILES
                    ),
                )
                plan.append((year, canon, group, by_stream[best][0]))
    return plan


def main():
    plan = build_plan()
    patches = [p for p in plan if SCI in p[2] and len(p[2]) > 1]
    keeps = [p for p in plan if p[2] == [SCI]]
    inserts = [p for p in plan if SCI not in p[2]]
    up_bytes = 0
    up_files = 0
    for year, canon, group, src in inserts:
        for archive_name, _, _ in FILES:
            fp = os.path.join(src, archive_name)
            if os.path.isfile(fp):
                up_files += 1
                up_bytes += os.path.getsize(fp)

    print(f"plan: {len(plan)} groups total")
    print(f"  sciences-only rows (untouched): {len(keeps)}")
    print(f"  shared rows to PATCH (widen streams, no upload): {len(patches)}")
    print(f"  new rows to INSERT: {len(inserts)}"
          f"  ({up_files} files, {up_bytes / 1048576:.0f} MB upload)")

    if DRY:
        print("dry run — stopping here.")
        return

    c = Client()

    done = 0
    for year, canon, group, _src in patches:
        c.patch_streams(year, canon, group)
        done += 1
        print(f"[patch {done}/{len(patches)}] {year} {SLUG[canon]} -> {len(group)} streams")

    done = 0
    for year, canon, group, src in inserts:
        group_slug = "-".join(STREAM_PATH[s] for s in group)
        folder = f"{year}/{group_slug}/{SLUG[canon]}"
        row = {
            "year": year,
            "stream": group[0],          # primary (legacy visibility)
            "streams": group,            # authoritative set
            "subject": canon,
            "file_size_bytes": 0,
        }
        size = 0
        for archive_name, storage_name, col in FILES:
            fp = os.path.join(src, archive_name)
            if not os.path.isfile(fp):
                continue
            object_path = f"{folder}/{storage_name}"
            size += os.path.getsize(fp)
            if not c.object_exists(object_path):  # resume support
                c.upload(object_path, fp)
            row[col] = (
                f"{c.url}/storage/v1/object/public/{BUCKET}/{object_path}"
            )
        row["file_size_bytes"] = size
        c.upsert(row)
        done += 1
        print(f"[insert {done}/{len(inserts)}] {year} {group_slug}/{SLUG[canon]}"
              f" ({size // 1024} KB)")

    print("done.")


if __name__ == "__main__":
    main()
