<?php

namespace App\Notifications;

use App\Models\Meeting;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class MeetingCancelledNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Meeting $meeting,
        public ?string $cancellerName = null
    ) {}

    /**
     * Get the notification's delivery channels.
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            return $notifiable->getNotificationChannelsFor('meeting_cancellations');
        }

        return ['database', 'mail'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $name = $this->cancellerName ?? $this->meeting->organizer?->name ?? 'The organizer';

        return (new MailMessage)
            ->subject("[Schedio Cancelled] {$this->meeting->title}")
            ->greeting("Hello {$notifiable->name},")
            ->line("The scheduled meeting **{$this->meeting->title}** has been cancelled by {$name}.")
            ->line("**Original Time:** " . $this->meeting->start_time->toDayDateTimeString())
            ->action('Open Workspace Calendar', url('/calendar'))
            ->line('Any automated reminders for this session have been dismissed.');
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     */
    public function toArray(object $notifiable): array
    {
        $name = $this->cancellerName ?? $this->meeting->organizer?->name ?? 'Organizer';

        return [
            'category' => 'meeting_cancellations',
            'title' => 'Meeting Cancelled',
            'message' => "The meeting '{$this->meeting->title}' (originally scheduled for " . $this->meeting->start_time->format('M d, h:i A') . ") was cancelled by {$name}.",
            'meeting_id' => $this->meeting->id,
            'meeting_title' => $this->meeting->title,
            'start_time' => $this->meeting->start_time->toIso8601String(),
            'action_url' => url('/calendar'),
            'action_text' => 'View Calendar',
            'icon' => 'calendar-x',
            'color' => 'rose',
        ];
    }
}
