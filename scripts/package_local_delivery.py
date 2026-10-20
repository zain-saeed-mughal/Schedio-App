"""Package source and a normal local-development APK, rejecting test secrets."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run():
    identities = json.loads((ROOT / "staging-test-credentials.local.json").read_text(encoding="utf-8-sig"))
    postgres = json.loads((ROOT / ".tools/staging/postgres-credentials.local.json").read_text())
    values = [v for k, v in identities.items() if k.endswith("_PASSWORD")] + list(postgres.values())
    needles = [v.encode(encoding) for v in values for encoding in ("utf-8", "utf-16-le")]

    def verify(data, name):
        if any(secret in data for secret in needles):
            raise RuntimeError("Secret scan rejected an artifact; no secret value printed: " + name)

    apk = ROOT / "schedio_mobile/build/app/outputs/flutter-apk/app-debug.apk"
    with zipfile.ZipFile(apk) as source:
        for name in source.namelist():
            verify(source.read(name), "APK entry " + name)
    files = subprocess.check_output(
        ["rg", "--files", "--hidden", "--no-require-git",
         "-g", "!deliverables/**", "-g", "!.tools/**", "-g", "!.git/**"], cwd=ROOT,
        text=True).splitlines()
    output = ROOT / "deliverables"
    output.mkdir(exist_ok=True)
    archive = output / "Schedio-staging-development-source.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as target:
        for name in sorted(files):
            path = ROOT / name
            if path.name in (".env", ".env.staging-local", ".env.staging-sqlite-local", "staging-test-credentials.local.json"):
                raise RuntimeError("Private configuration unexpectedly included.")
            data = path.read_bytes()
            verify(data, name)
            target.writestr(Path(name).as_posix(), data)
    delivered_apk = output / "Schedio-emulator-debug.apk"
    shutil.copy2(apk, delivered_apk)
    lines = []
    for path in (archive, delivered_apk):
        digest = hashlib.file_digest(path.open("rb"), "sha256").hexdigest()
        lines.append(f"{digest}  {path.name}")
    (output / "Schedio-local-SHA256SUMS.txt").write_text("\n".join(lines) + "\n")
    print(f"Packaged {len(files)} source files and normal emulator APK; test/database secret scans passed.")


if __name__ == "__main__":
    run()
