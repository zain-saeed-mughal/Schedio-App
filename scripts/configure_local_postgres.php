<?php
// Local-only cluster bootstrap. Never accepts remote host/database arguments.
$root = dirname(__DIR__);
try {
    $secrets = json_decode(file_get_contents($root.'/.tools/staging/postgres-credentials.local.json'), true, 512, JSON_THROW_ON_ERROR);
    $pdo = new PDO('pgsql:host=127.0.0.1;port=55432;dbname=postgres',
        'schedio_cluster_admin', $secrets['admin_password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $exists = $pdo->query("SELECT 1 FROM pg_roles WHERE rolname='schedio_staging_app'")->fetchColumn();
    if (! $exists) {
        $pdo->exec('CREATE ROLE schedio_staging_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '.$pdo->quote($secrets['app_password']));
    }
    if (! $pdo->query("SELECT 1 FROM pg_database WHERE datname='schedio_staging'")->fetchColumn()) {
        $pdo->exec('CREATE DATABASE schedio_staging OWNER schedio_staging_app');
    }
    $pdo->exec('REVOKE CONNECT ON DATABASE schedio_staging FROM PUBLIC');
    $pdo->exec('GRANT CONNECT ON DATABASE schedio_staging TO schedio_staging_app');
    $path = $root.'/Schedio-main/.env.staging-local';
    $contents = file_get_contents($path);
    if (! preg_match('/^APP_ENV=staging\r?$/m', $contents)) {
        throw new RuntimeException('Not the expected local staging environment.');
    }
    foreach (['DB_CONNECTION' => 'pgsql', 'DB_HOST' => '127.0.0.1', 'DB_PORT' => '55432',
        'DB_DATABASE' => 'schedio_staging', 'DB_USERNAME' => 'schedio_staging_app',
        'DB_PASSWORD' => $secrets['app_password'], 'DB_URL' => 'null'] as $key => $value) {
        $line = $key.'="'.$value.'"';
        $contents = preg_match('/^'.$key.'=/m', $contents)
            ? preg_replace_callback('/^'.$key.'=.*$/m', fn () => $line, $contents)
            : $contents.PHP_EOL.$line.PHP_EOL;
    }
    // Only the ignored local staging file is updated; the application's .env is untouched.
    file_put_contents($path, $contents);
    echo "Local PostgreSQL role/database ready; local staging configuration updated. No credentials printed.\n";
} catch (Throwable $error) {
    fwrite(STDERR, "Local PostgreSQL configuration failed; exception details suppressed to protect credentials.\n");
    exit(1);
}
