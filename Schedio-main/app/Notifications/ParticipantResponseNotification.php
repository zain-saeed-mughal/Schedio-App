<?php

namespace App\Notifications;

use App\Models\Meeting;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class ParticipantResponseNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Meeting $meeting,
        public User $participant,
        public string $status,
        public ?string $notes = null
    ) {}

    /**
     * Get the notification's delivery channels.
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            return $notifiable->getNotificationChannelsFor('participant_responses');
        }

        return ['database'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $statusUpper = strtoupper($this->status);

        $mail = (new MailMessage)
            ->subject("[Schedio RSVP: {$statusUpper}] {$this->participant->name} responded to '{$this->meeting->title}'")
            ->greeting("Hello {$notifiable->name},")
            ->line("**{$this->participant->name}** has responded **{$this->status}** to your meeting invitation for **{$this->meeting->title}**.")
            ->line("**Meeting Time:** " . $this->meeting->start_time->toDayDateTimeString());

        if ($this->notes) {
            $mail->line("**Note from participant:** \"{$this->notes}\"");
        }

        $mail->action('View Meeting & Attendees', url("/meetings/{$this->meeting->id}"));

        return $mail;
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     */
    public function toArray(object $notifiable): array
    {
        $statusColors = [
            'accepted' => 'emerald',
            'declined' => 'rose',
            'tentative' => 'amber',
        ];

        return [
            'category' => 'participant_responses',
            'title' => "RSVP: {$this->participant->name} (" . ucfirst($this->status) . ")",
            'message' => "{$this->participant->name} marked their attendance as " . strtoupper($this->status) . " for '{$this->meeting->title}'." . ($this->notes ? " Note: \"{$this->notes}\"" : ''),
            'meeting_id' => $this->meeting->id,
            'meeting_title' => $this->meeting->title,
            'participant_id' => $this->participant->id,
            'participant_name' => $this->participant->name,
            'status' => $this->status,
            'notes' => $this->notes,
            'action_url' => url("/meetings/{$this->meeting->id}"),
            'action_text' => 'View Attendees',
            'icon' => 'user-check',
            'color' => $statusColors[$this->status] ?? 'indigo',
        ];
    }
}
