<?php

namespace App\Services;

use App\Jobs\ProcessReminderJob;
use App\Models\AuditLog;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class ReminderEngineService
{
    /**
     * Dispatch all due pending reminders to the queue.
     * Called automatically every minute by Laravel Scheduler.
     *
     * @return int Count of dispatched reminders
     */
    public function dispatchDueReminders(): int
    {
        $now = now();

        // Find all pending reminders due now or past due within reasonable window
        $dueReminders = Reminder::where('status', 'pending')
            ->where('remind_at', '<=', $now)
            ->lockForUpdate()
            ->get();

        $dispatchedCount = 0;

        foreach ($dueReminders as $reminder) {
            // Mark temporarily as queued to prevent concurrent scheduler overlap
            $reminder->update(['status' => 'queued']);
            ProcessReminderJob::dispatch($reminder->id);
            $dispatchedCount++;
        }

        return $dispatchedCount;
    }

    /**
     * Create or sync reminders for a meeting's participants.
     *
     * @param Meeting $meeting
     * @param int $minutesBefore (e.g. 5, 10, 15, 30, 60, 1440)
     * @param string $channel ('in_app', 'email', 'both')
     * @return Collection<Reminder>
     */
    public function scheduleMeetingReminders(Meeting $meeting, int $minutesBefore = 15, string $channel = 'both'): Collection
    {
        if ($minutesBefore <= 0) {
            return collect();
        }

        $remindAt = $meeting->start_time->copy()->subMinutes($minutesBefore);

        // Fetch all accepted and pending participants + organizer
        $userIds = $meeting->participants()->pluck('users.id')->push($meeting->organizer_id)->unique();

        $createdReminders = collect();

        foreach ($userIds as $userId) {
            // Prevent duplicate reminder for same user, meeting, and remind_at
            $exists = Reminder::where('user_id', $userId)
                ->where('remindable_type', Meeting::class)
                ->where('remindable_id', $meeting->id)
                ->where('status', 'pending')
                ->where('remind_at', $remindAt)
                ->exists();

            if (!$exists) {
                $clientInfo = !empty($meeting->metadata['client_name']) ? " with {$meeting->metadata['client_name']}" : '';
                $linkInfo = $meeting->meeting_link ? " Join link: {$meeting->meeting_link}" : '';

                $reminder = Reminder::create([
                    'user_id' => $userId,
                    'title' => "Upcoming Call: {$meeting->title}",
                    'message' => "Your meeting '{$meeting->title}'{$clientInfo} starts at {$meeting->start_time->format('h:i A')} ({$minutesBefore} minutes from now).{$linkInfo}",
                    'remindable_type' => Meeting::class,
                    'remindable_id' => $meeting->id,
                    'remind_at' => $remindAt,
                    'channel' => $channel,
                    'status' => 'pending',
                    'payload' => [
                        'meeting_id' => $meeting->id,
                        'meeting_link' => $meeting->meeting_link,
                        'minutes_before' => $minutesBefore,
                        'client_name' => $meeting->metadata['client_name'] ?? null,
                    ],
                ]);

                $createdReminders->push($reminder);
            }
        }

        return $createdReminders;
    }

    /**
     * Reschedule all active reminders when a meeting's start time changes.
     *
     * @param Meeting $meeting
     * @param Carbon $oldStartTime
     * @return int Count of adjusted reminders
     */
    public function handleMeetingRescheduled(Meeting $meeting, Carbon $oldStartTime): int
    {
        $pendingReminders = Reminder::where('remindable_type', Meeting::class)
            ->where('remindable_id', $meeting->id)
            ->whereIn('status', ['pending', 'queued'])
            ->get();

        $count = 0;
        foreach ($pendingReminders as $reminder) {
            $minutesBefore = $reminder->payload['minutes_before'] ?? 15;
            $newRemindAt = $meeting->start_time->copy()->subMinutes((int) $minutesBefore);

            $reminder->update([
                'remind_at' => $newRemindAt,
                'status' => 'pending',
                'message' => "Rescheduled: Your meeting '{$meeting->title}' is starting at {$meeting->start_time->format('h:i A')} ({$minutesBefore} minutes from now).",
            ]);
            $count++;
        }

        return $count;
    }

    /**
     * Dismiss all pending reminders when a meeting is cancelled.
     *
     * @param Meeting $meeting
     * @return int
     */
    public function handleMeetingCancelled(Meeting $meeting): int
    {
        return Reminder::where('remindable_type', Meeting::class)
            ->where('remindable_id', $meeting->id)
            ->whereIn('status', ['pending', 'queued'])
            ->update([
                'status' => 'dismissed',
                'message' => DB::raw("message || ' [Cancelled]'"),
            ]);
    }
}
