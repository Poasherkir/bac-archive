#!/usr/bin/env python3
"""Tiny static server for the admin dashboard.

Plain `python -m http.server` on Windows serves .js with a MIME type pulled
from the registry (often `application/x-js`), which browsers REJECT for ES
modules. This forces the correct JS MIME so the dashboard loads everywhere.

Usage:
    python serve.py           # http://localhost:5173
    python serve.py 8080      # custom port
"""
import os
import sys
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

# Always serve the folder this script lives in (the admin dashboard),
# regardless of where python was invoked from.
os.chdir(os.path.dirname(os.path.abspath(__file__)))


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".css": "text/css",
        ".html": "text/html",
        ".json": "application/json",
        ".svg": "image/svg+xml",
    }

    def end_headers(self):
        # avoid stale-cache surprises while editing
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5173
    print(f"Serving admin dashboard at http://localhost:{port}  (Ctrl+C to stop)")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
