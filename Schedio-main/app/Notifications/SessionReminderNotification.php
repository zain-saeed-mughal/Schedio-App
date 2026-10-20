<?php

namespace App\Notifications;

use App\Models\Reminder;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class SessionReminderNotification extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(
        public Reminder $reminder
    ) {}

    /**
     * Get the notification's delivery channels.
     *
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        if (method_exists($notifiable, 'getNotificationChannelsFor')) {
            $userChannels = $notifiable->getNotificationChannelsFor('meeting_reminders');
            $reminderChannel = $this->reminder->channel ?? 'both';

            if ($reminderChannel === 'email') {
                return in_array('mail', $userChannels, true) ? ['mail'] : [];
            } elseif ($reminderChannel === 'in_app') {
                return in_array('database', $userChannels, true) ? ['database'] : [];
            }

            return $userChannels;
        }

        $channel = $this->reminder->channel ?? 'both';

        if ($channel === 'email') {
            return ['mail'];
        } elseif ($channel === 'in_app') {
            return ['database'];
        }

        return ['database', 'mail'];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $mail = (new MailMessage)
            ->subject("[Schedio Reminder] {$this->reminder->title}")
            ->greeting("Hello {$notifiable->name},")
            ->line($this->reminder->message ?? 'You have an upcoming scheduled session.')
            ->line("Scheduled Time: " . $this->reminder->remind_at->toDayDateTimeString());

        if ($this->reminder->payload && isset($this->reminder->payload['meeting_link']) && $this->reminder->payload['meeting_link']) {
            $mail->action('Join Video Meeting', $this->reminder->payload['meeting_link']);
        } elseif ($this->reminder->payload && isset($this->reminder->payload['meeting_id'])) {
            $mail->action('View Meeting Details', url("/meetings/{$this->reminder->payload['meeting_id']}"));
        } else {
            $mail->action('Open Schedio Workspace', url('/dashboard'));
        }

        return $mail->line('Thank you for using Schedio Enterprise Scheduling.');
    }

    /**
     * Get the array representation of the notification for in-app database storage.
     *
     * @return array<string, mixed>
     */
    public function toArray(object $notifiable): array
    {
        $actionUrl = url('/dashboard');
        if ($this->reminder->payload && isset($this->reminder->payload['meeting_id'])) {
            $actionUrl = url("/meetings/{$this->reminder->payload['meeting_id']}");
        }

        return [
            'category' => 'meeting_reminders',
            'reminder_id' => $this->reminder->id,
            'title' => $this->reminder->title,
            'message' => $this->reminder->message,
            'remind_at' => $this->reminder->remind_at->toIso8601String(),
            'remindable_type' => $this->reminder->remindable_type,
            'remindable_id' => $this->reminder->remindable_id,
            'meeting_id' => $this->reminder->payload['meeting_id'] ?? null,
            'action_url' => $actionUrl,
            'action_text' => 'View Session',
            'icon' => 'bell',
            'color' => 'amber',
            'payload' => $this->reminder->payload,
        ];
    }
}
