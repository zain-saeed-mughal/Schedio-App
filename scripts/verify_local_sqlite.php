<?php
$root = dirname(__DIR__);
require $root.'/Schedio-main/vendor/autoload.php';
$app = require $root.'/Schedio-main/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.staging-sqlite-local');
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$connection = Illuminate\Support\Facades\DB::connection();
$expected = realpath($root.'/.tools/staging/sqlite-compat/schedio_staging.sqlite');
if (! $expected || ! $app->environment('staging')
    || $connection->getDriverName() !== 'sqlite'
    || realpath($connection->getDatabaseName()) !== $expected
    || config('mail.default') !== 'log') {
    fwrite(STDERR, "Refusing: isolated SQLite compatibility checks failed.\n");
    exit(1);
}
echo json_encode([
    'driver' => 'sqlite', 'database' => $expected,
    'version' => $connection->selectOne('select sqlite_version() as version')->version,
    'foreign_keys' => $connection->selectOne('PRAGMA foreign_keys')->foreign_keys,
    'journal_mode' => $connection->selectOne('PRAGMA journal_mode')->journal_mode,
    'users' => App\Models\User::withoutGlobalScopes()->count(),
    'failed_jobs' => $connection->table('failed_jobs')->count(),
    'mail_transport' => config('mail.default'),
], JSON_PRETTY_PRINT), PHP_EOL;
