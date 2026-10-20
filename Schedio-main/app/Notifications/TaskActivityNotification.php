<?php

namespace App\Notifications;

use App\Models\Task;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class TaskActivityNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Task $task,
        public string $activityType, // 'assigned', 'status_changed', 'completed'
        public ?User $actor = null,
        public ?string $detail = null
    ) {}

    /**
     * Get the notification's delivery channels.
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            return $notifiable->getNotificationChannelsFor('task_activity');
        }

        return ['database', 'mail'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $actorName = $this->actor?->name ?? 'System';

        $subjectMap = [
            'assigned' => "[Schedio Task Assigned] {$this->task->title}",
            'status_changed' => "[Schedio Task Updated] {$this->task->title}",
            'completed' => "[Schedio Task Completed] {$this->task->title}",
        ];

        $mail = (new MailMessage)
            ->subject($subjectMap[$this->activityType] ?? "[Schedio Task Activity] {$this->task->title}")
            ->greeting("Hello {$notifiable->name},");

        if ($this->activityType === 'assigned') {
            $mail->line("**{$actorName}** assigned a new action item to you:")
                 ->line("**Task:** {$this->task->title}")
                 ->line("**Priority:** " . strtoupper($this->task->priority))
                 ->line("**Due Date:** " . ($this->task->due_date ? $this->task->due_date->toFormattedDateString() : 'None'));
        } elseif ($this->activityType === 'completed') {
            $mail->line("The task **{$this->task->title}** was marked completed by **{$actorName}**.");
        } else {
            $mail->line("Task **{$this->task->title}** status was updated: {$this->detail} by **{$actorName}**.");
        }

        if ($this->task->meeting_id) {
            $mail->action('View Meeting & Tasks', url("/meetings/{$this->task->meeting_id}"));
        } else {
            $mail->action('Open Workspace Dashboard', url('/dashboard'));
        }

        return $mail;
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     */
    public function toArray(object $notifiable): array
    {
        $actorName = $this->actor?->name ?? 'System';

        $titleMap = [
            'assigned' => 'New Task Assigned',
            'status_changed' => 'Task Status Updated',
            'completed' => 'Task Marked Completed',
        ];

        $messageMap = [
            'assigned' => "{$actorName} assigned you task '{$this->task->title}' (Priority: " . strtoupper($this->task->priority) . ").",
            'status_changed' => "Task '{$this->task->title}' status was updated: {$this->detail}.",
            'completed' => "Task '{$this->task->title}' was completed by {$actorName}.",
        ];

        $actionUrl = $this->task->meeting_id ? url("/meetings/{$this->task->meeting_id}") : url('/dashboard');

        return [
            'category' => 'task_activity',
            'title' => $titleMap[$this->activityType] ?? 'Task Activity',
            'message' => $messageMap[$this->activityType] ?? "Task update for '{$this->task->title}'.",
            'task_id' => $this->task->id,
            'task_title' => $this->task->title,
            'activity_type' => $this->activityType,
            'actor_id' => $this->actor?->id,
            'actor_name' => $actorName,
            'action_url' => $actionUrl,
            'action_text' => 'View Task',
            'icon' => $this->activityType === 'completed' ? 'check-circle' : 'clipboard-list',
            'color' => $this->activityType === 'completed' ? 'emerald' : 'amber',
        ];
    }
}
