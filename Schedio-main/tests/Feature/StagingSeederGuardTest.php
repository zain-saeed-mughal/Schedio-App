<?php

namespace Tests\Feature;

use Database\Seeders\StagingTestSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use RuntimeException;
use Tests\TestCase;

class StagingSeederGuardTest extends TestCase
{
    use RefreshDatabase;

    public function test_seeder_refuses_production_even_when_opted_in(): void
    {
        config(['app.env' => 'production', 'staging_tests.enabled' => true]);
        $this->app->detectEnvironment(fn () => 'production');
        try {
            (new StagingTestSeeder)->run();
            $this->fail('Production seeding must be refused.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('requires opted-in staging', $e->getMessage());
        }
        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('companies', 0);
    }

    public function test_seeder_refuses_a_database_without_the_explicit_staging_name(): void
    {
        config(['app.env' => 'staging', 'staging_tests.enabled' => true]);
        $this->app->detectEnvironment(fn () => 'staging');
        try {
            (new StagingTestSeeder)->run();
            $this->fail('An unrecognized database must be refused.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('dedicated schedio_staging database', $e->getMessage());
        }
        $this->assertDatabaseCount('users', 0);
    }
}
