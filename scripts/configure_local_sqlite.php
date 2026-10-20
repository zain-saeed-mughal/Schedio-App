<?php
// Creates only a new, disposable local compatibility environment.
$root = str_replace('\\', '/', dirname(__DIR__));
$directory = $root.'/.tools/staging/sqlite-compat';
if (! is_dir($directory)) { mkdir($directory, 0700, true); }
$database = $directory.'/schedio_staging.sqlite';
if (! is_file($database)) { touch($database); }
$environment = $root.'/Schedio-main/.env.staging-sqlite-local';
if (is_file($environment)) {
    echo "SQLite compatibility environment already exists; preserved.\n";
    exit;
}
$values = [
    'APP_NAME' => 'Schedio SQLite compatibility', 'APP_ENV' => 'staging',
    'APP_KEY' => 'base64:'.base64_encode(random_bytes(32)), 'APP_DEBUG' => 'false',
    'APP_URL' => 'http://127.0.0.1:8090', 'DB_CONNECTION' => 'sqlite',
    'DB_DATABASE' => $database, 'DB_URL' => 'null', 'DB_FOREIGN_KEYS' => 'true',
    'SESSION_DRIVER' => 'file', 'SESSION_COOKIE' => 'schedio_sqlite_compat_session',
    'CACHE_STORE' => 'array', 'QUEUE_CONNECTION' => 'database',
    'MAIL_MAILER' => 'log', 'MAIL_FROM_ADDRESS' => 'local@demo.schedio.test',
    'STAGING_TESTS_ENABLED' => 'true',
    'STAGING_TEST_CREDENTIALS_FILE' => $root.'/staging-test-credentials.local.json',
];
$lines = [];
foreach ($values as $key => $value) { $lines[] = $key.'="'.$value.'"'; }
file_put_contents($environment, implode(PHP_EOL, $lines).PHP_EOL);
echo "Separate local SQLite configuration created; no credentials printed.\n";
