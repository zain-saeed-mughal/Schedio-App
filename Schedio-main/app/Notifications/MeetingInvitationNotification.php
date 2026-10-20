<?php

namespace App\Notifications;

use App\Models\Meeting;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class MeetingInvitationNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Meeting $meeting
    ) {}

    /**
     * Get the notification's delivery channels based on user preferences.
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            return $notifiable->getNotificationChannelsFor('meeting_invitations');
        }

        return ['database', 'mail'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $organizerName = $this->meeting->organizer?->name ?? 'A team member';
        $locationStr = $this->meeting->meeting_link ? 'Online Video Call' : ($this->meeting->location ?? 'Virtual Meeting');

        $mail = (new MailMessage)
            ->subject("[Schedio Invitation] {$this->meeting->title}")
            ->greeting("Hello {$notifiable->name},")
            ->line("You have been invited by **{$organizerName}** to an upcoming meeting.")
            ->line("**Title:** {$this->meeting->title}")
            ->line("**Date & Time:** " . $this->meeting->start_time->toDayDateTimeString())
            ->line("**Format:** {$locationStr}");

        if ($this->meeting->meeting_link) {
            $mail->line("**Video Conference Link:** {$this->meeting->meeting_link}");
        }

        $mail->action('View Meeting & RSVP', url("/meetings/{$this->meeting->id}"))
            ->line('Please confirm your attendance in the Schedio workspace.');

        return $mail;
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     */
    public function toArray(object $notifiable): array
    {
        $organizerName = $this->meeting->organizer?->name ?? 'A colleague';
        $locationStr = $this->meeting->meeting_link ? 'Video Call' : 'Online';

        return [
            'category' => 'meeting_invitations',
            'title' => 'New Meeting Invitation',
            'message' => "{$organizerName} invited you to '{$this->meeting->title}' scheduled for " . $this->meeting->start_time->format('M d, h:i A') . " ({$locationStr}).",
            'meeting_id' => $this->meeting->id,
            'meeting_title' => $this->meeting->title,
            'organizer_id' => $this->meeting->organizer_id,
            'organizer_name' => $organizerName,
            'start_time' => $this->meeting->start_time->toIso8601String(),
            'end_time' => $this->meeting->end_time->toIso8601String(),
            'meeting_link' => $this->meeting->meeting_link,
            'action_url' => url("/meetings/{$this->meeting->id}"),
            'action_text' => 'View & RSVP',
            'icon' => 'calendar-plus',
            'color' => 'indigo',
        ];
    }
}
