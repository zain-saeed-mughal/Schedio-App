<?php

namespace App\Notifications;

use App\Models\Meeting;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class MeetingUpdatedNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Meeting $meeting,
        public array $changedFields = []
    ) {}

    /**
     * Get the notification's delivery channels.
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            return $notifiable->getNotificationChannelsFor('meeting_updates');
        }

        return ['database', 'mail'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $mail = (new MailMessage)
            ->subject("[Schedio Updated] {$this->meeting->title}")
            ->greeting("Hello {$notifiable->name},")
            ->line("The meeting details for **{$this->meeting->title}** have been updated by the organizer.")
            ->line("**Updated Start Time:** " . $this->meeting->start_time->toDayDateTimeString());

        if (!empty($this->changedFields)) {
            $mail->line("Updated elements: " . implode(', ', $this->changedFields));
        }

        $mail->action('Review Updated Meeting', url("/meetings/{$this->meeting->id}"))
            ->line('Please review the updated details in your Schedio calendar.');

        return $mail;
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     */
    public function toArray(object $notifiable): array
    {
        $changesDesc = !empty($this->changedFields) ? ' (' . implode(', ', $this->changedFields) . ')' : '';

        return [
            'category' => 'meeting_updates',
            'title' => 'Meeting Details Updated',
            'message' => "The meeting '{$this->meeting->title}' was updated{$changesDesc}. Starts at " . $this->meeting->start_time->format('M d, h:i A') . ".",
            'meeting_id' => $this->meeting->id,
            'meeting_title' => $this->meeting->title,
            'organizer_id' => $this->meeting->organizer_id,
            'start_time' => $this->meeting->start_time->toIso8601String(),
            'action_url' => url("/meetings/{$this->meeting->id}"),
            'action_text' => 'Review Meeting',
            'icon' => 'calendar-refresh',
            'color' => 'sky',
        ];
    }
}
