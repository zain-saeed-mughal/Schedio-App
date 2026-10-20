"""Concurrent local Laravel requests; both servers must use schedio_staging.

Verifies the selected local Laravel configuration before running. No remote URL or credential output is supported.
"""
import concurrent.futures
import datetime as dt
import json
from pathlib import Path
import subprocess
import threading
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]

def verify_isolation(driver="pgsql"):
    assert driver in ("pgsql", "sqlite")
    result = subprocess.run(
        [str(ROOT / ".tools/php/php.exe"), str(ROOT / ("scripts/verify_local_sqlite.php" if driver == "sqlite" else "scripts/verify_local_postgres.php"))],
        cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError("Local staging isolation verification failed; diagnostics suppressed.")
    evidence = json.loads(result.stdout)
    assert evidence["driver"] == driver
    if driver == "pgsql":
        assert evidence["database"] == "schedio_staging"


def request(port, path, method="GET", data=None, token=None):
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/api/v1/{path}",
        json.dumps(data).encode() if data is not None else None,
        headers, method=method)
    try:
        response = urllib.request.urlopen(req, timeout=40)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.loads(response.read())


def run(driver="pgsql"):
    verify_isolation(driver)
    primary, secondary = (8090, 8091) if driver == "sqlite" else (8088, 8089)
    credentials = json.loads((ROOT / "staging-test-credentials.local.json").read_text(encoding="utf-8-sig"))
    status, login = request(primary, "auth/login", "POST", {
        "email": credentials["ADMIN_A_EMAIL"], "password": credentials["ADMIN_A_PASSWORD"],
        "device_name": "Local staging contention verification",
    })
    assert status == 200
    token, meeting_ids, room_id = login["token"], [], None
    try:
        marker = "STAGING-CONTENTION-" + uuid.uuid4().hex[:8]
        status, room = request(primary, "rooms", "POST",
                               {"name": marker, "capacity": 2, "location": "Local test"}, token)
        assert status == 201
        status, rooms = request(primary, "rooms?search=" + marker, token=token)
        assert status == 200 and len(rooms["data"]) == 1
        room_id = rooms["data"][0]["id"]
        start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=180)).replace(
            minute=0, second=0, microsecond=0)
        payload = {"title": marker, "type": "in_person", "room_id": room_id,
                   "start_time": start.isoformat(),
                   "end_time": (start + dt.timedelta(hours=1)).isoformat(), "timezone": "UTC"}
        barrier = threading.Barrier(2)

        def create(port):
            barrier.wait(timeout=10)
            return request(port, "meetings", "POST", payload, token)

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(create, [primary, secondary]))
        status, records = request(primary, "meetings?search=" + marker, token=token)
        if status == 200:
            meeting_ids.extend(item["id"] for item in records["data"])
        assert sorted(code for code, _ in results) == [201, 422], (
            f"Concurrent booking must produce one creation and one conflict; received {[code for code, _ in results]}.")
        assert status == 200 and len(records["data"]) == 1
        print("PASS Two independent Laravel servers concurrently booked the same isolated staging room.")
        print("PASS Exactly one HTTP 201, one HTTP 422, and one persisted meeting.")
    finally:
        for meeting_id in meeting_ids:
            request(primary, f"meetings/{meeting_id}", "DELETE", token=token)
        if room_id is not None:
            request(primary, f"rooms/{room_id}", "DELETE", token=token)
        request(primary, "auth/logout", "POST", token=token)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver", choices=("pgsql", "sqlite"), default="pgsql")
    run(parser.parse_args().driver)
