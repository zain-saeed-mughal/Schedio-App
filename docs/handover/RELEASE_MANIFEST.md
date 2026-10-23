# Schedio Android Release Manifest

Final release: **r7**, built 2026-10-24 from branch `main` (base commit `ea1d5c7` plus the uncommitted changes listed in `FINAL_QA_REPORT.md`; not yet committed).

| Item | Value |
|---|---|
| App name | Schedio |
| Application ID | `live.schedio.schedio_mobile` |
| Version | 1.0.0 (version code 1) |
| Minimum Android | 7.0 (API 24) |
| Target / compile SDK | 36 (Android 16) |
| Flutter / Dart | 3.47.7 / 3.13.5 |
| Build flags | `--release --dart-define=APP_ENV=production --dart-define=PUSH_ENABLED=true` |
| API | `https://schedio.live/api/v1/` only (HTTPS; no development or staging addresses in the compiled code) |
| Backend verified against | API v2.1, 60/60 routes live (2026-10-24) |
| Firebase project | `schedio-app-bc57b` |
| Cleartext traffic | Off (`usesCleartextTraffic=false`) |
| App data backup | Off (`allowBackup=false`) |
| Debuggable | No |
| Notification setup | Channel `schedio_high_importance_channel` (high importance), `FLUTTER_NOTIFICATION_CLICK` intent filter, default icon kept in release |
| Signing | Upload key, APK Signature Scheme v2 verified |
| Certificate SHA-256 | `80:7F:48:2B:D9:29:65:8C:8D:99:84:51:3A:9B:1D:FB:76:87:1F:07:1C:64:3F:33:ED:BA:E5:1F:44:A0:E1:81` |
| Certificate SHA-1 | `16:8D:B7:72:F8:8F:95:A0:DC:15:6F:37:79:FA:9B:F0:23:BF:7B:9D` |
| Signing files in package | None (no keystore or `key.properties` packaged) |

## Artifacts (in `release-builds/`, git-ignored)

| File | Size | SHA-256 |
|---|---|---|
| `Schedio-1.0.0-production-push-20261024-r7.apk` | 59.6 MB | `68b901fe1e64395d9733d50e7eaa592a326831156d8dea47ecdd5eaeec2af10f` |
| `Schedio-1.0.0-production-push-20261024-r7.aab` | 58.2 MB | `9e66ff404d1897c656b77040f7ecfe7261be5750b0c7444b6f934554efc70bcc` |

Checksums also in `release-builds/SHA256SUMS-20261024-r7.txt`. Verify on Windows with `certutil -hashfile <file> SHA256`, or on macOS/Linux with `sha256sum <file>`.

The r7 APK is installed on the test phone (Xiaomi 2404ARN45A, Android 16), opens signed in to the sandbox account, and shows the dashboard without errors.

## Earlier builds (kept, superseded)

| Build | Notes |
|---|---|
| `...-20261023.apk` / `...-production-20261023.aab` | First production builds |
| r2 | Three reported bugs fixed, notification tap fix |
| r3 | Push registration retry and Settings push status |
| r4 | Timezone fix for all times sent to the API |
| r5 | Tolerant account, calendar and dashboard parsing |
| r6 | Notification badge follows the inbox |
| **r7** | **Task edit and delete enabled (API v2.1); edit/delete/status controls for tasks, clients and events when the server omits `can_manage`; task edit keeps its meeting link (final)** |

## Play Store notes

- Upload the `.aab`. With Play App Signing, Google re-signs for distribution; add Google's app-signing SHA-1 and SHA-256 (Play Console → App integrity) to the Firebase Android app so push keeps working for Play installs.
- Before each new upload, increase `version:` in `pubspec.yaml` (for example `1.0.1+2`).
- The AAB has not been uploaded; that needs the client's approval and Play Console access.
