<?php

namespace App\Console\Commands;

use App\Services\ReminderEngineService;
use Illuminate\Console\Command;

class ProcessDueRemindersCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'schedio:process-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Scan and dispatch due pending session reminders to the background queue';

    /**
     * Execute the console command.
     */
    public function handle(ReminderEngineService $reminderEngine): int
    {
        $this->info('Scanning for due reminders...');

        $dispatched = $reminderEngine->dispatchDueReminders();

        $this->info("Successfully dispatched {$dispatched} due reminder(s) to the queue.");

        return Command::SUCCESS;
    }
}
