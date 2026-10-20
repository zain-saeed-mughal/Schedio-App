<?php

namespace App\Services;

use App\Models\Meeting;
use App\Models\Task;
use App\Models\User;
use App\Notifications\MeetingCancelledNotification;
use App\Notifications\MeetingInvitationNotification;
use App\Notifications\MeetingUpdatedNotification;
use App\Notifications\ParticipantResponseNotification;
use App\Notifications\TaskActivityNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

class NotificationDispatchService
{
    /**
     * Send invitations to participants of a meeting.
     *
     * @param Meeting $meeting
     * @param array<int>|null $onlyUserIds (optional specific user IDs to notify)
     */
    public function notifyMeetingInvitation(Meeting $meeting, ?array $onlyUserIds = null): void
    {
        $query = $meeting->participants();
        if ($onlyUserIds !== null) {
            $query->whereIn('users.id', $onlyUserIds);
        }

        // Don't notify organizer with invitation
        $participants = $query->where('users.id', '!=', $meeting->organizer_id)->get();

        foreach ($participants as $participant) {
            try {
                $participant->notify(new MeetingInvitationNotification($meeting));
            } catch (\Throwable $e) {
                Log::warning("Failed to deliver meeting invitation notification to user {$participant->id}: " . $e->getMessage());
            }
        }
    }

    /**
     * Send update notification to all participants when meeting details change.
     *
     * @param Meeting $meeting
     * @param array $changedFields
     */
    public function notifyMeetingUpdated(Meeting $meeting, array $changedFields = []): void
    {
        $participants = $meeting->participants()
            ->where('users.id', '!=', auth()->id())
            ->get();

        foreach ($participants as $participant) {
            try {
                $participant->notify(new MeetingUpdatedNotification($meeting, $changedFields));
            } catch (\Throwable $e) {
                Log::warning("Failed to deliver meeting updated notification to user {$participant->id}: " . $e->getMessage());
            }
        }
    }

    /**
     * Send cancellation notification to all participants when meeting is cancelled.
     *
     * @param Meeting $meeting
     * @param string|null $cancellerName
     */
    public function notifyMeetingCancelled(Meeting $meeting, ?string $cancellerName = null): void
    {
        $participants = $meeting->participants()
            ->where('users.id', '!=', auth()->id())
            ->get();

        foreach ($participants as $participant) {
            try {
                $participant->notify(new MeetingCancelledNotification($meeting, $cancellerName));
            } catch (\Throwable $e) {
                Log::warning("Failed to deliver meeting cancelled notification to user {$participant->id}: " . $e->getMessage());
            }
        }
    }

    /**
     * Notify organizer when a participant responds to an RSVP.
     *
     * @param Meeting $meeting
     * @param User $participant
     * @param string $status
     * @param string|null $notes
     */
    public function notifyParticipantResponse(Meeting $meeting, User $participant, string $status, ?string $notes = null): void
    {
        $organizer = $meeting->organizer;
        if ($organizer && $organizer->id !== $participant->id) {
            try {
                $organizer->notify(new ParticipantResponseNotification($meeting, $participant, $status, $notes));
            } catch (\Throwable $e) {
                Log::warning("Failed to deliver RSVP notification to organizer {$organizer->id}: " . $e->getMessage());
            }
        }
    }

    /**
     * Notify user when a task is assigned, updated, or completed.
     *
     * @param Task $task
     * @param string $activityType ('assigned', 'status_changed', 'completed')
     * @param User|null $actor
     * @param string|null $detail
     */
    public function notifyTaskActivity(Task $task, string $activityType, ?User $actor = null, ?string $detail = null): void
    {
        // If assigned or status changed, notify assignee
        if ($task->assigned_to && (!$actor || $actor->id !== $task->assigned_to)) {
            $assignee = $task->assignee ?? User::find($task->assigned_to);
            if ($assignee) {
                try {
                    $assignee->notify(new TaskActivityNotification($task, $activityType, $actor, $detail));
                } catch (\Throwable $e) {
                    Log::warning("Failed to deliver task notification to assignee {$assignee->id}: " . $e->getMessage());
                }
            }
        }

        // If completed or updated by assignee, notify task creator if different
        if ($activityType === 'completed' && $task->created_by && (!$actor || $actor->id !== $task->created_by)) {
            $creator = $task->creator ?? User::find($task->created_by);
            if ($creator && $creator->id !== $task->assigned_to) {
                try {
                    $creator->notify(new TaskActivityNotification($task, $activityType, $actor, $detail));
                } catch (\Throwable $e) {
                    Log::warning("Failed to deliver task completed notification to creator {$creator->id}: " . $e->getMessage());
                }
            }
        }
    }
}
