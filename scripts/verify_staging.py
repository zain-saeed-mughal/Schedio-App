"""Exercise real HTTP web/API round trips against an explicitly isolated target.

Uses only Python's standard library. Never prints credentials or bearer tokens.
"""
import argparse
import datetime as dt
import html
import http.cookiejar
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--credentials", type=Path, required=True)
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    target = urllib.parse.urlparse(base)
    if target.hostname not in ("127.0.0.1", "localhost", "staging.schedio.live"):
        raise RuntimeError("Only loopback or staging.schedio.live is allowed.")
    if target.hostname == "staging.schedio.live" and target.scheme != "https":
        raise RuntimeError("Remote staging requires HTTPS.")
    credentials = json.loads(args.credentials.read_text(encoding="utf-8-sig"))
    marker = "STAGING-E2E-" + uuid.uuid4().hex[:10]
    tokens, records = {}, []

    def request(path, method="GET", data=None, token=None, browser=None):
        headers = {"Accept": "application/json" if browser is None else "text/html"}
        if token:
            headers["Authorization"] = "Bearer " + token
        body = None
        if data is not None:
            headers["Content-Type"] = "application/json" if browser is None else "application/x-www-form-urlencoded"
            body = (json.dumps(data) if browser is None else urllib.parse.urlencode(data, doseq=True)).encode()
        req = urllib.request.Request(base + path, body, headers, method=method)
        opener = browser or urllib.request.build_opener()
        try:
            response = opener.open(req, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            text = response.read().decode()
            content = json.loads(text) if "application/json" in response.headers.get("Content-Type", "") else text
            return response.status, content

    def check(condition, label):
        if not condition:
            raise AssertionError(label)
        print("PASS " + label, flush=True)

    def api(key, path, method="GET", data=None, expected=200):
        status, content = request("/api/v1/" + path, method, data, tokens.get(key))
        check(status == expected, f"{key} {method} {path}: HTTP {expected}")
        return content

    try:
        for key in ("ADMIN_A", "EMPLOYEE_A", "EMPLOYEE_B"):
            result = api(key, "auth/login", "POST", {
                "email": credentials[key + "_EMAIL"], "password": credentials[key + "_PASSWORD"],
                "device_name": "Isolated staging HTTP verification",
            })
            tokens[key] = result["token"]
            account = api(key, "auth/me")["data"]
            check(account["email"] == credentials[key + "_EMAIL"], key + " authenticated identity")
        api("ADMIN_A", "admin/registration-requests")
        api("EMPLOYEE_A", "admin/registration-requests", expected=403)
        api("EMPLOYEE_B", "admin/registration-requests", expected=403)
        api("EMPLOYEE_A", "rooms", "POST", {"name": marker, "capacity": 2, "location": "Test"}, 403)
        start = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=90)).replace(minute=0, second=0, microsecond=0)
        payload = {"title": marker, "start_time": start.isoformat(),
                   "end_time": (start + dt.timedelta(hours=1)).isoformat(), "timezone": "UTC", "type": "virtual"}
        meeting = api("ADMIN_A", "meetings", "POST", payload, 201)["data"]["id"]
        records.append(("meetings", meeting))
        api("EMPLOYEE_A", f"meetings/{meeting}", expected=404)
        api("EMPLOYEE_B", f"meetings/{meeting}", expected=404)
        employee_id = api("EMPLOYEE_A", "auth/me")["data"]["id"]
        payload["participant_ids"] = [employee_id]
        api("ADMIN_A", f"meetings/{meeting}", "PUT", payload)
        api("EMPLOYEE_A", f"meetings/{meeting}")
        api("EMPLOYEE_A", f"meetings/{meeting}/rsvp", "POST", {"status": "accepted"})
        check(any(p["id"] == employee_id and p["status"] == "accepted"
                  for p in api("ADMIN_A", f"meetings/{meeting}")["data"]["participants"]), "RSVP synchronized")

        browser = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        _, login_html = request("/login", browser=browser)
        csrf = html.unescape(re.search(r'name="_token"\s+value="([^"]+)"', login_html).group(1))
        status, _ = request("/login", "POST", {"_token": csrf, "email": credentials["ADMIN_A_EMAIL"],
                                             "password": credentials["ADMIN_A_PASSWORD"]}, browser=browser)
        check(status == 200, "Browser session login")
        status, page = request(f"/meetings/{meeting}", browser=browser)
        check(status == 200 and marker in page, "API-created meeting appears in rendered web page")
        csrf = html.unescape(re.search(r'name="csrf-token"\s+content="([^"]+)"', page).group(1))
        changed = marker + "-web-edited"
        web_payload = {k: v for k, v in payload.items() if k != "participant_ids"}
        web_payload.update({"_token": csrf, "_method": "PUT", "title": changed, "participant_ids[]": [employee_id]})
        status, _ = request(f"/meetings/{meeting}", "POST", web_payload, browser=browser)
        check(status == 200, "Existing web meeting update succeeds")
        check(api("ADMIN_A", f"meetings/{meeting}")["data"]["title"] == changed, "Web edit appears through mobile API")
        api("ADMIN_A", f"meetings/{meeting}/cancel", "PATCH")
        status, page = request(f"/meetings/{meeting}", browser=browser)
        check(status == 200 and "cancelled" in page.lower(), "Mobile cancellation appears on web")

        for module, payload in [
            ("clients", {"company_name": marker, "contact_name": "Test contact", "status": "discovery"}),
            ("tasks", {"title": marker, "priority": "high", "assigned_to": employee_id}),
            ("events", {"title": marker, "start_time": start.isoformat(),
                        "end_time": (start + dt.timedelta(hours=1)).isoformat(),
                        "category": "general", "is_company_wide": True}),
            ("rooms", {"name": marker, "capacity": 2, "location": "Test"}),
        ]:
            api("ADMIN_A", module, "POST", payload, 201)
            result = api("ADMIN_A", module + "?search=" + marker)["data"]
            check(len(result) == 1, module + " created once")
            record_id = result[0]["id"]
            records.append((module, record_id))
            api("EMPLOYEE_B", f"{module}/{record_id}", expected=404)
            check(not api("EMPLOYEE_B", module + "?search=" + marker)["data"], module + " list tenant isolation")
            if module == "tasks":
                api("EMPLOYEE_A", f"tasks/{record_id}/status", "PATCH", {"status": "completed"})
                check(api("ADMIN_A", f"tasks/{record_id}")["data"]["status"] == "completed", "Assigned employee task completion")
                request(f"/tasks/{record_id}/status", "POST",
                        {"_token": csrf, "_method": "PATCH", "status": "in_progress"}, browser=browser)
                check(api("EMPLOYEE_A", f"tasks/{record_id}")["data"]["status"] == "in_progress", "Web task edit appears for mobile assignee")
            if module == "clients":
                api("ADMIN_A", f"clients/{record_id}/status", "PATCH", {"status": "onboarded"})
                status, page = request(f"/clients/{record_id}", browser=browser)
                check(status == 200 and "onboarded" in page.lower(), "Mobile client stage appears on web")
        print("PASS Live HTTP round trips and account/role/tenant checks completed.")
    finally:
        for module, record_id in reversed(records):
            if module == "tasks":
                request(f"/api/v1/tasks/{record_id}/status", "PATCH", {"status": "cancelled"}, tokens.get("ADMIN_A"))
            else:
                request(f"/api/v1/{module}/{record_id}", "DELETE", token=tokens.get("ADMIN_A"))
        for token in tokens.values():
            request("/api/v1/auth/logout", "POST", token=token)
            status, _ = request("/api/v1/auth/me", token=token)
            check(status == 401, "Logged-out token rejected")


if __name__ == "__main__":
    run()
