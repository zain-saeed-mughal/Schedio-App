<?php
// Read only. Fail closed unless Laravel resolves the intended local database.
$root = dirname(__DIR__);
require $root.'/Schedio-main/vendor/autoload.php';
$app = require $root.'/Schedio-main/bootstrap/app.php';
$app->loadEnvironmentFrom('.env.staging-local');
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$connection = Illuminate\Support\Facades\DB::connection();
if (! $app->environment('staging')
    || $connection->getDriverName() !== 'pgsql'
    || $connection->getDatabaseName() !== 'schedio_staging'
    || $connection->getConfig('host') !== '127.0.0.1'
    || (string) $connection->getConfig('port') !== '55432'
    || config('mail.default') !== 'log') {
    fwrite(STDERR, "Refusing: local staging isolation checks failed.\n");
    exit(1);
}
$record = $connection->selectOne('select current_database() as database, version() as version');
echo json_encode([
    'driver' => $connection->getDriverName(),
    'host' => $connection->getConfig('host'),
    'port' => $connection->getConfig('port'),
    'database' => $record->database,
    'version' => $record->version,
    'users' => App\Models\User::withoutGlobalScopes()->count(),
    'failed_jobs' => $connection->table('failed_jobs')->count(),
    'mail_transport' => config('mail.default'),
], JSON_PRETTY_PRINT), PHP_EOL;
