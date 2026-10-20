"""Verify inline-client atomicity through either isolated local Laravel API."""
import argparse
import datetime as dt
import json
import uuid
from verify_postgres_contention import ROOT, request, verify_isolation


def run(driver):
    verify_isolation(driver)
    port = 8090 if driver == "sqlite" else 8088
    credentials = json.loads((ROOT / "staging-test-credentials.local.json").read_text(encoding="utf-8-sig"))
    tokens, meeting_id, client_id = {}, None, None
    try:
        for who in ("ADMIN_A", "EMPLOYEE_B"):
            status, result = request(port, "auth/login", "POST", {
                "email": credentials[who + "_EMAIL"], "password": credentials[who + "_PASSWORD"],
                "device_name": "Local feature acceptance"})
            assert status == 200
            tokens[who] = result["token"]
        marker = "INLINE-" + uuid.uuid4().hex[:10]
        start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=340)).replace(minute=0, second=0, microsecond=0)
        payload = {"title": marker, "type": "virtual", "timezone": "UTC",
                   "start_time": start.isoformat(), "end_time": (start + dt.timedelta(hours=1)).isoformat(),
                   "is_client_meeting": True, "save_as_client": True,
                   "client_name": "Guest", "client_company": marker, "client_email": "guest@example.test"}
        status, result = request(port, "meetings", "POST", payload, tokens["ADMIN_A"])
        assert status == 201
        meeting_id, client_id = result["data"]["id"], result["data"]["client_id"]
        status, client = request(port, f"clients/{client_id}", token=tokens["ADMIN_A"])
        assert status == 200 and client["data"]["status"] == "scheduled"
        assert client["data"]["contact_email"] == "guest@example.test"
        status, _ = request(port, f"clients/{client_id}", token=tokens["EMPLOYEE_B"])
        assert status == 404
        status, _ = request(port, "meetings", "POST", payload, tokens["ADMIN_A"])
        assert status == 422
        status, clients = request(port, "clients?search=" + marker, token=tokens["ADMIN_A"])
        assert status == 200 and len(clients["data"]) == 1
        print("PASS Inline client and meeting persisted together with scheduled pipeline stage.")
        print("PASS Cross-company access denied; conflicting retry creates no duplicate client.")
    finally:
        if meeting_id:
            request(port, f"meetings/{meeting_id}", "DELETE", token=tokens["ADMIN_A"])
        if client_id:
            request(port, f"clients/{client_id}", "DELETE", token=tokens["ADMIN_A"])
        for token in tokens.values():
            request(port, "auth/logout", "POST", token=token)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver", choices=("pgsql", "sqlite"), default="pgsql")
    run(parser.parse_args().driver)
