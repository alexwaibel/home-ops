#!/usr/bin/env python3

import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import urllib.request

BEET = "/lsiopy/bin/beet"
CONFIG_DIR = Path(os.environ.get("BEETSDIR", "/config"))
STATE_PATH = CONFIG_DIR / "enrichment-state.json"
LIDARR_URL = os.environ["LIDARR_URL"].rstrip("/")
LIDARR_API_KEY = os.environ["LIDARR_API_KEY"]
LIDARR_MEDIA_ROOT = Path(os.environ["LIDARR_MEDIA_ROOT"])
BEETS_MEDIA_ROOT = Path(os.environ["BEETS_MEDIA_ROOT"])
WEBHOOK_PORT = int(os.environ.get("BEETS_WEBHOOK_PORT", "8338"))
BACKFILL_ON_START = os.environ.get("BACKFILL_ON_START", "false").lower() == "true"
MAX_REQUEST_BYTES = 1024 * 1024

work_queue = queue.Queue()
work_lock = threading.Lock()
queued_album_ids = set()
retrigger_album_ids = set()
active_album_id = None


def lidarr_get(path):
    request = urllib.request.Request(
        f"{LIDARR_URL}/api/v1/{path}",
        headers={"X-Api-Key": LIDARR_API_KEY},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def load_state():
    if not STATE_PATH.exists():
        return {}
    with STATE_PATH.open(encoding="utf-8") as state_file:
        state = json.load(state_file)
    if not isinstance(state, dict):
        raise ValueError(f"{STATE_PATH} must contain a JSON object")
    return state


def save_state(state):
    temporary_path = STATE_PATH.with_suffix(".tmp")
    with temporary_path.open("w", encoding="utf-8") as state_file:
        json.dump(state, state_file, indent=2, sort_keys=True)
        state_file.write("\n")
    temporary_path.replace(STATE_PATH)


def local_path(lidarr_path):
    remote = Path(lidarr_path)
    relative = remote.relative_to(LIDARR_MEDIA_ROOT)
    return BEETS_MEDIA_ROOT / relative


def album_signature(release_id, files):
    details = []
    for track_file in files:
        path = local_path(track_file["path"])
        stat = path.stat()
        details.append(
            {
                "id": track_file["id"],
                "path": str(path),
                "size": stat.st_size,
                "mtime_ns": stat.st_mtime_ns,
            }
        )
    payload = json.dumps(
        {"release_id": release_id, "files": sorted(details, key=lambda item: item["id"])},
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def process_album(album, state):
    releases = [release for release in album["releases"] if release["monitored"]]
    if len(releases) != 1:
        print(
            f"Skipping album {album['id']} ({album['title']}): "
            f"expected one monitored release, found {len(releases)}",
            flush=True,
        )
        return

    track_files = lidarr_get(f"trackfile?albumId={album['id']}")
    if not track_files:
        return

    release_id = releases[0]["foreignReleaseId"]
    paths = [local_path(track_file["path"]) for track_file in track_files]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"Lidarr track files are not mounted in Beets: {missing}")

    album_path = Path(os.path.commonpath([str(path.parent) for path in paths]))
    signature = album_signature(release_id, track_files)
    state_key = str(album["id"])
    album_state = state.get(state_key, {})
    if (
        album_state.get("status") == "enriched"
        and album_state.get("signature") == signature
    ):
        return

    database = Path(f"/tmp/beets-{album['id']}.db")
    database.unlink(missing_ok=True)
    print(
        f"Enriching {album['title']} with MusicBrainz release {release_id}",
        flush=True,
    )
    result = subprocess.run(
        [
            BEET,
            "-l",
            str(database),
            "-v",
            "import",
            "--quiet",
            "--search-id",
            release_id,
            str(album_path),
        ],
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Beets failed for album {album['id']} with exit code {result.returncode}"
        )

    listing = subprocess.run(
        [BEET, "-l", str(database), "ls", "-f", "$path"],
        check=True,
        capture_output=True,
        text=True,
    )
    imported_paths = [line for line in listing.stdout.splitlines() if line]
    status = "enriched" if imported_paths else "skipped"
    if status == "enriched":
        signature = album_signature(release_id, track_files)
    state[state_key] = {
        "release_id": release_id,
        "signature": signature,
        "status": status,
    }
    save_state(state)
    print(f"{status.capitalize()} {album['title']}", flush=True)


def enqueue(album_id):
    global active_album_id
    with work_lock:
        if album_id == active_album_id:
            retrigger_album_ids.add(album_id)
            return
        if album_id in queued_album_ids:
            return
        queued_album_ids.add(album_id)
        work_queue.put(album_id)


def worker():
    global active_album_id
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    state = load_state()
    while True:
        album_id = work_queue.get()
        try:
            with work_lock:
                queued_album_ids.discard(album_id)
                active_album_id = album_id
            album = lidarr_get(f"album/{album_id}")
            process_album(album, state)
        except Exception as error:
            print(
                f"ERROR: album {album_id} enrichment failed: {error}",
                file=sys.stderr,
                flush=True,
            )
        finally:
            with work_lock:
                if album_id in retrigger_album_ids:
                    retrigger_album_ids.discard(album_id)
                    queued_album_ids.add(album_id)
                    work_queue.put(album_id)
                active_album_id = None
            work_queue.task_done()


def get_key(mapping, key):
    for candidate, value in mapping.items():
        if candidate.lower() == key.lower():
            return value
    return None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, message, *args):
        print(f"HTTP: {message % args}", flush=True)

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path != "/health":
            self.send_json(404, {"error": "not found"})
            return
        self.send_json(
            200,
            {
                "status": "ok",
                "activeAlbumId": active_album_id,
                "queuedAlbums": work_queue.qsize(),
            },
        )

    def do_POST(self):
        if self.path != "/lidarr":
            self.send_json(404, {"error": "not found"})
            return
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > MAX_REQUEST_BYTES:
                raise ValueError("invalid Content-Length")
            payload = json.loads(self.rfile.read(content_length))
            event_type = get_key(payload, "eventType")
            album = get_key(payload, "album")
            if event_type == "Test":
                self.send_json(200, {"status": "ok"})
                return
            if not isinstance(album, dict):
                raise ValueError("webhook does not include an album")
            album_id = get_key(album, "id")
            if not isinstance(album_id, int):
                raise ValueError("webhook album id is invalid")
            enqueue(album_id)
            self.send_json(202, {"status": "queued", "albumId": album_id})
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json(400, {"error": str(error)})


def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    threading.Thread(target=worker, daemon=True, name="beets-worker").start()

    if BACKFILL_ON_START:
        for album in lidarr_get("album"):
            enqueue(album["id"])

    server = ThreadingHTTPServer(("0.0.0.0", WEBHOOK_PORT), Handler)
    print(f"Listening for Lidarr webhooks on port {WEBHOOK_PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
