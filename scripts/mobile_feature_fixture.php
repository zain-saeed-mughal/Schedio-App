<?php
// Only the verified local PostgreSQL test identities may be temporarily changed.
require __DIR__.'/verify_local_postgres.php';
use App\Models\{Department, User};
use Illuminate\Support\Facades\DB;
$path = dirname(__DIR__).'/.tools/staging/mobile-feature-fixture.json';
$action = $argv[1] ?? '';
$user = User::withoutGlobalScopes()->where('email', 'employee.a@demo.schedio.test')->firstOrFail();
if ($user->company?->name !== 'Schedio Test Company A') { throw new RuntimeException('Fixture company mismatch.'); }
if ($action === 'prepare') {
    if (is_file($path)) { throw new RuntimeException('Restore the existing fixture first.'); }
    $state = $user->only(['role', 'title', 'department_id', 'approval_status', 'approved_at', 'approved_by', 'is_active', 'rejection_reason']);
    $department = Department::create(['company_id' => $user->company_id,
        'name' => 'Mobile Acceptance Department', 'code' => 'MOB-'.bin2hex(random_bytes(4)), 'is_active' => true]);
    file_put_contents($path, json_encode(['user_id' => $user->id, 'state' => $state, 'department_id' => $department->id]));
    $user->update(['approval_status' => 'pending', 'role' => 'employee', 'title' => null]);
    echo "Local approval fixture prepared.\n";
} elseif ($action === 'restore') {
    $state = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
    if ($state['user_id'] !== $user->id) { throw new RuntimeException('Fixture identity mismatch.'); }
    DB::transaction(function () use ($user, $state) {
        $user->update($state['state']);
        Department::where('company_id', $user->company_id)->whereKey($state['department_id'])->delete();
    });
    unlink($path);
    echo "Local approval fixture restored.\n";
} else { throw new RuntimeException('Use prepare or restore.'); }
