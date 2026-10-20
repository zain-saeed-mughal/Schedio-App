"""Real local API checks for notes, calendar and queued notification delivery."""
import datetime as dt
import json
import time
import urllib.parse
import uuid

from verify_postgres_contention import ROOT, request, verify_isolation


def run(driver="pgsql"):
    verify_isolation(driver)
    port = 8090 if driver == "sqlite" else 8088
    credentials = json.loads((ROOT / "staging-test-credentials.local.json").read_text(encoding="utf-8-sig"))
    tokens, meeting_id = {}, None

    def call(who, path, method="GET", data=None, expected=200):
        status, body = request(port, path, method, data, tokens.get(who))
        assert status == expected, f"{path}: expected {expected}, received {status}"
        return body

    try:
        users = {}
        for who in ("ADMIN_A", "EMPLOYEE_A", "EMPLOYEE_B"):
            login = call(who, "auth/login", "POST", {
                "email": credentials[who + "_EMAIL"], "password": credentials[who + "_PASSWORD"],
                "device_name": "Local staging workflow verification",
            })
            tokens[who], users[who] = login["token"], login["user"]
        marker = "STAGING-WORKFLOW-" + uuid.uuid4().hex[:8]
        start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=210)).replace(
            minute=0, second=0, microsecond=0)
        payload = {"title": marker, "type": "virtual", "timezone": "UTC",
                   "start_time": start.isoformat(),
                   "end_time": (start + dt.timedelta(hours=1)).isoformat(),
                   "participant_ids": [users["EMPLOYEE_A"]["id"]]}
        meeting_id = call("ADMIN_A", "meetings", "POST", payload, 201)["data"]["id"]
        call("ADMIN_A", f"meetings/{meeting_id}/notes", "POST", {"agenda": marker}, 201)
        note = call("ADMIN_A", f"meetings/{meeting_id}/notes")["data"][0]["id"]
        call("ADMIN_A", f"meeting-notes/{note}", "PUT", {"agenda": marker + " revised"})
        assert call("EMPLOYEE_A", f"meeting-notes/{note}")["data"]["agenda"] == marker + " revised"
        call("EMPLOYEE_B", f"meeting-notes/{note}", expected=404)
        print("PASS Note edits refetch correctly; invited participant can read; other company receives 404.")
        query = urllib.parse.urlencode({"start": start.isoformat(),
                                        "end": (start + dt.timedelta(days=1)).isoformat()})
        assert any(x["id"] == meeting_id for x in call("EMPLOYEE_A", "calendar/feed?" + query)["data"])
        assert not any(x["id"] == meeting_id for x in call("EMPLOYEE_B", "calendar/feed?" + query)["data"])
        print("PASS Real staging calendar feed includes invited meetings and excludes the other company.")
        notification = None
        for _ in range(30):
            inbox = call("EMPLOYEE_A", "notifications")["data"]
            notification = next((x for x in inbox if x["data"].get("meeting_id") == meeting_id), None)
            if notification:
                break
            time.sleep(1)
        assert notification, "Invitation was not delivered by the local queue worker."
        notification_id = notification["id"]
        call("EMPLOYEE_B", f"notifications/{notification_id}/read", "PATCH", expected=404)
        call("EMPLOYEE_A", f"notifications/{notification_id}/read", "PATCH")
        assert next(x for x in call("EMPLOYEE_A", "notifications")["data"]
                    if x["id"] == notification_id)["read_at"] is not None
        call("EMPLOYEE_A", f"notifications/{notification_id}/unread", "PATCH")
        assert next(x for x in call("EMPLOYEE_A", "notifications")["data"]
                    if x["id"] == notification_id)["read_at"] is None
        print("PASS Queued invitation delivered; read/unread persisted; cross-company inbox mutation denied.")
        call("EMPLOYEE_A", f"meetings/{meeting_id}/rsvp", "POST", {"status": "accepted"})
        assert any(x["id"] == users["EMPLOYEE_A"]["id"] and x["status"] == "accepted"
                   for x in call("ADMIN_A", f"meetings/{meeting_id}")["data"]["participants"])
        call("ADMIN_A", f"meetings/{meeting_id}/cancel", "PATCH")
        assert not any(x["id"] == meeting_id for x in call("EMPLOYEE_A", "calendar/feed?" + query)["data"])
        print("PASS RSVP synchronized and cancelled meeting removed from calendar.")
    finally:
        if meeting_id is not None:
            call("ADMIN_A", f"meetings/{meeting_id}", "DELETE")
        for who in tokens:
            call(who, "auth/logout", "POST")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver", choices=("pgsql", "sqlite"), default="pgsql")
    run(parser.parse_args().driver)
