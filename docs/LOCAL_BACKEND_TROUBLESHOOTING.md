# Local Backend Troubleshooting

Applies to the isolated local test API started by `scripts/start_local_sqlite.ps1` (portable PHP in `.tools/php`, SQLite database in `.tools/staging/sqlite-compat`). It does not affect the production website.

## HTTP returns HTML fatal errors while Artisan works (fixed 2026-10-22)

### Symptoms

- Every HTTP request returned status 200 with an HTML error page instead of JSON.
- `storage/logs/laravel.log` showed `Cannot instantiate interface RecursiveIterator` at `vendor/symfony/finder/Finder.php:795` during `LoadConfiguration`, followed by `Log [] is not defined`, `Target class [view] does not exist` and `A facade root has not been set`.
- `php artisan` commands kept working.

### Root cause

OPcache shared memory corruption on Windows, not a dependency or PHP-version problem.

- `Finder.php:795` is `new \RecursiveIteratorIterator(...)`, a standard class. PHP resolving it to the interface `RecursiveIterator` means the cached class table was wrong, not the code.
- `artisan serve` runs `php -S`, which uses OPcache (`opcache.enable=On`). Artisan CLI commands don't (`opcache.enable_cli=Off`). That is why the CLI worked and HTTP failed.
- On Windows, all PHP processes from the same binary attach to one OPcache shared-memory segment. Several servers were running (8090, 8091 and extra ones on 8092 and on the LAN address). When a process attaches to a segment created by another process at a different memory address, cached class pointers resolve to the wrong classes. The failures started the moment a new 8090 server was started on the LAN address.

Evidence:

| Test | Result |
|---|---|
| Fresh `php -S` with `-d opcache.enable=0`, same code, env and database | `200 application/json` |
| Identical command with OPcache enabled | HTML fatal error |
| `symfony/finder` version in `composer.lock` | v7.4.19, compatible; no `composer update` needed |

### Fix

`scripts/start_local_sqlite.ps1` now:

1. Writes `.tools/php/dev-ini/zz-local-dev.ini` (`opcache.enable=0`, git-ignored) and passes it to PHP through `PHP_INI_SCAN_DIR`, so the `artisan serve` child processes run without OPcache. Nothing in `php.ini`, `vendor/` or the application changes.
2. Accepts `-BindHost` (default `127.0.0.1`). Use `-BindHost 0.0.0.0` for Wi-Fi testing instead of starting servers by hand.
3. Accepts `-Restart`, which stops only this project's PHP servers. Stale processes keep the corrupted shared memory alive.
4. Fails unless the API answers with `application/json`.

Restart command:

```powershell
.\scripts\start_local_sqlite.ps1 -BindHost 0.0.0.0 -Restart
```

### Verification (2026-10-22)

| Check | Result |
|---|---|
| `php artisan --version --env=staging-sqlite-local` | Laravel 12.69.2 |
| `GET http://192.168.9.211:8090/api/v1/auth/registration-options` | 200 `application/json` |
| Login with the Admin A staging account | Token issued |
| `GET auth/me` and `GET dashboard` with the token | 200 |
| `GET auth/me` without a token | 401 JSON |
| Logout, then `auth/me` with the old token | 200, then 401 |
| Phone over Wi-Fi only (no USB tunnel): sign-in and dashboard | PASS (`session_persistence_test`) |
| Phone restart keeps the session | PASS |

Data preserved: the SQLite database and the three test accounts were not modified by the fix.

## Phone cannot reach the PC over Wi-Fi

If the phone gets "No route to host" or a timeout on `http://<PC IP>:8090`, Windows Firewall is blocking inbound connections. Set the Wi-Fi network to Private and allow `.tools\php\php.exe` on Private networks. Never open it on Public networks.

## Website pages return 500 locally

`/login` and other web pages fail with "Vite manifest not found" because the web frontend assets are not built on this PC. The mobile API does not need them, and the web frontend is out of scope for the mobile team.
