"""Prepare the existing isolated Git checkout; never commits or pushes."""
import json
import ipaddress
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / ".tools/public-publish"


def run():
    remote = subprocess.check_output(["git", "-C", str(TARGET), "remote", "get-url", "origin"], text=True).strip()
    if remote != "https://github.com/zain-saeed-mughal/Schedio-App.git":
        raise RuntimeError("Unexpected publishing checkout.")
    secrets = []
    for path in (ROOT / "staging-test-credentials.local.json", ROOT / ".tools/staging/postgres-credentials.local.json"):
        values = json.loads(path.read_text(encoding="utf-8-sig"))
        secrets.extend(v for k, v in values.items() if "password" in k.lower() and isinstance(v, str))
    for path in (ROOT / "Schedio-main").glob(".env*"):
        if path.name == ".env.example":
            continue
        for line in path.read_text(errors="ignore").splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            value = value.strip().strip("\"'")
            if any(term in key.upper() for term in ("PASSWORD", "SECRET", "TOKEN", "APP_KEY")) and len(value) > 12:
                secrets.append(value)
    needles = [v.encode(enc) for v in secrets for enc in ("utf-8", "utf-16-le")]
    files = subprocess.check_output(["rg", "--files", "--hidden", "--no-require-git",
        "-g", "!.tools/**", "-g", "!deliverables/**", "-g", "!.git/**"], cwd=ROOT, text=True).splitlines()
    patterns = [r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----",
                r"gh[pousr]_[A-Za-z0-9]{30,}", r"github_pat_[A-Za-z0-9_]{30,}",
                r"AKIA[0-9A-Z]{16}", r"sk_live_[A-Za-z0-9]{16,}"]
    count = 0
    for name in files:
        relative = Path(name)
        if relative.parts[0] == "docs" and relative.suffix.lower() != ".md":
            continue
        if relative.parts[0] not in ("Schedio-main", "schedio_mobile", "docs", "scripts", "README.md", ".gitignore"):
            continue
        if relative.name == "local.properties" or ".git" in relative.parts:
            continue
        data = (ROOT / relative).read_bytes()
        if any(secret in data for secret in needles):
            raise RuntimeError("Known secret detected in " + name)
        text = data.decode("utf-8", errors="ignore")
        if any(re.search(pattern, text) for pattern in patterns):
            raise RuntimeError("Credential pattern detected in " + name)
        if relative.suffix == ".md":
            # Keep private operational details in local documents only.
            text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
                lambda m: m[0] if ipaddress.ip_address(m[0]).is_private else "<production-server>", text)
            text = re.sub(r"SSH port `\d+`", "the private SSH port", text)
            text = re.sub(r"/home/[^/\s]+/schedio-releases/current", "<production-checkout>", text)
            text = re.sub(r"`[\w-]+-deploy`", "the production deployment account", text)
            text = text.replace(str(ROOT), "<workspace>").replace(ROOT.as_posix(), "<workspace>")
            data = text.encode("utf-8")
        destination = TARGET / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        count += 1
    print(f"Prepared {count} public source/documentation files; known-secret and credential-pattern scans passed.")


if __name__ == "__main__":
    run()
