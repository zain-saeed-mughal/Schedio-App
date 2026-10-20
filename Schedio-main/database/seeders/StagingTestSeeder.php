<?php

namespace Database\Seeders;

use App\Models\{Company, User};
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class StagingTestSeeder extends Seeder
{
    public function run(): void
    {
        $connection = DB::connection();
        $database = str_replace('\\', '/', $connection->getDatabaseName());
        if (! app()->environment('staging', 'staging-local', 'staging-sqlite-local') || config('app.env') !== 'staging'
            || ! config('staging_tests.enabled')
            || ! in_array($connection->getDriverName(), ['sqlite', 'pgsql'], true)
            || ! in_array(basename($database), ['schedio_staging', 'schedio_staging.sqlite'], true)) {
            throw new RuntimeException('Test seeding requires opted-in staging and a dedicated schedio_staging database.');
        }
        $path = config('staging_tests.credentials_file');
        if (! is_string($path) || ! is_file($path)) {
            throw new RuntimeException('A local staging credentials file is required.');
        }
        $credentials = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        $identities = [
            ['ADMIN_A', 'admin.a@demo.schedio.test', 'Schedio Test Company A', 'super_admin'],
            ['EMPLOYEE_A', 'employee.a@demo.schedio.test', 'Schedio Test Company A', 'employee'],
            ['EMPLOYEE_B', 'employee.b@demo.schedio.test', 'Schedio Test Company B', 'employee'],
        ];
        foreach ($identities as [$key, $email]) {
            if (($credentials[$key.'_EMAIL'] ?? null) !== $email
                || strlen($credentials[$key.'_PASSWORD'] ?? '') < 24) {
                throw new RuntimeException('Expected test identities and random passwords of at least 24 characters.');
            }
        }
        DB::transaction(function () use ($identities, $credentials) {
            // Refuse a nonempty unmarked database, even if its environment was mislabeled.
            if (Company::whereNull('settings->staging_fixture')->exists()
                || Company::where('settings->staging_fixture', '!=', 'schedio-e2e')->exists()
                || User::withoutGlobalScopes()->whereNotIn('email', array_column($identities, 1))->exists()) {
                throw new RuntimeException('Refusing to seed a database containing non-fixture companies or users.');
            }
            foreach ($identities as [$key, $email, $companyName, $role]) {
                $company = Company::firstOrCreate(['name' => $companyName], [
                    'status' => 'active', 'settings' => ['staging_fixture' => 'schedio-e2e'],
                ]);
                $user = User::withoutGlobalScopes()->firstOrNew(['email' => $email]);
                $user->fill([
                    'name' => str_replace('_', ' ', $key),
                    'company_id' => $company->id, 'role' => $role,
                    'password' => $credentials[$key.'_PASSWORD'],
                    'approval_status' => 'approved', 'approved_at' => now(),
                    'is_active' => true, 'timezone' => 'Asia/Karachi',
                    'username' => strtolower(str_replace('_', '-', $key)).'-staging',
                ]);
                $user->email_verified_at = now();
                $user->save();
            }
        });
        $this->command?->info('Three isolated staging test accounts are ready. No credentials printed.');
    }
}
