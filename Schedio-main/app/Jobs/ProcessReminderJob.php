<?php

namespace App\Jobs;

use App\Models\AuditLog;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Notifications\SessionReminderNotification;
use Carbon\Carbon;
use Exception;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class ProcessReminderJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $backoff = 30;

    public function __construct(
        public int $reminderId
    ) {}

    /**
     * Execute the reminder processing job.
     */
    public function handle(): void
    {
        $reminder = Reminder::with(['user', 'remindable'])->find($this->reminderId);

        if (!$reminder) {
            return;
        }

        // 1. Check if already processed to prevent duplicate sends
        if ($reminder->status === 'sent') {
            return;
        }

        // 2. Check if parent entity was cancelled or soft deleted
        if ($reminder->remindable_type === Meeting::class) {
            $meeting = Meeting::withTrashed()->find($reminder->remindable_id);
            if (!$meeting || $meeting->trashed() || $meeting->status === 'cancelled') {
                $reminder->update([
                    'status' => 'dismissed',
                    'message' => ($reminder->message ?? '') . ' [Cancelled due to meeting cancellation]',
                ]);
                return;
            }
        }

        try {
            DB::transaction(function () use ($reminder) {
                // Lock row to prevent race conditions
                $lockedReminder = Reminder::where('id', $reminder->id)->lockForUpdate()->first();

                if ($lockedReminder->status === 'sent') {
                    return;
                }

                // Send Notification (In-App Database + Email)
                if ($reminder->user) {
                    $reminder->user->notify(new SessionReminderNotification($reminder));
                }

                // Mark reminder as sent
                $lockedReminder->update([
                    'status' => 'sent',
                    'sent_at' => now(),
                ]);

                // Record Audit Log
                AuditLog::create([
                    'user_id' => $reminder->user_id,
                    'action' => 'reminder_dispatched',
                    'auditable_type' => Reminder::class,
                    'auditable_id' => $reminder->id,
                    'description' => "Reminder '{$reminder->title}' dispatched via {$reminder->channel}.",
                    'metadata' => [
                        'channel' => $reminder->channel,
                        'remind_at' => $reminder->remind_at->toIso8601String(),
                    ],
                ]);
            });
        } catch (Exception $e) {
            Log::error("Failed to process reminder ID {$reminder->id}: " . $e->getMessage());

            $reminder->update([
                'status' => 'failed',
                'payload' => array_merge($reminder->payload ?? [], ['error' => $e->getMessage()]),
            ]);

            throw $e;
        }
    }
}
