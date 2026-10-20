<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Meeting;
use App\Models\MeetingNote;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MeetingNoteController extends Controller
{
    /**
     * Store a newly created meeting note for a specific meeting.
     */
    public function store(Request $request, Meeting $meeting): RedirectResponse|JsonResponse
    {
        $user = Auth::user();

        // Check permission to contribute to meeting notes
        if (!$user->isSuperAdmin() && $meeting->organizer_id !== $user->id) {
            $isParticipant = $meeting->participants()->where('users.id', $user->id)->exists();
            if (!$isParticipant) {
                abort(403, 'Unauthorized to add notes to this meeting session.');
            }
        }

        $validated = $request->validate([
            'agenda' => ['nullable', 'string'],
            'discussion' => ['nullable', 'string'],
            'decisions' => ['nullable', 'string'],
            'action_items' => ['nullable', 'string'],
            'follow_up_date' => ['nullable', 'date'],
            'attachments_text' => ['nullable', 'string'], // Comma/newline separated doc links or titles
        ]);

        $attachments = [];
        if (!empty($validated['attachments_text'])) {
            $lines = preg_split('/[\r\n,]+/', $validated['attachments_text']);
            foreach ($lines as $line) {
                $trimmed = trim($line);
                if ($trimmed) {
                    $attachments[] = [
                        'name' => filter_var($trimmed, FILTER_VALIDATE_URL) ? parse_url($trimmed, PHP_URL_HOST) ?? 'External Link' : $trimmed,
                        'url' => filter_var($trimmed, FILTER_VALIDATE_URL) ? $trimmed : null,
                        'text' => $trimmed,
                    ];
                }
            }
        }

        $note = MeetingNote::create([
            'meeting_id' => $meeting->id,
            'user_id' => $user->id,
            'agenda' => $validated['agenda'] ?? null,
            'discussion' => $validated['discussion'] ?? null,
            'decisions' => $validated['decisions'] ?? null,
            'action_items' => $validated['action_items'] ?? null,
            'follow_up_date' => !empty($validated['follow_up_date']) ? Carbon::parse($validated['follow_up_date']) : null,
            'attachments' => $attachments ?: null,
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'meeting_note_added',
            'auditable_type' => MeetingNote::class,
            'auditable_id' => $note->id,
            'description' => "Meeting notes recorded for '{$meeting->title}' by {$user->name}.",
            'new_values' => $note->toArray(),
        ]);

        if ($request->wantsJson()) {
            return response()->json([
                'success' => true,
                'message' => 'Meeting notes saved successfully.',
                'note' => $note->load('author'),
            ]);
        }

        return back()->with('success', 'Meeting notes recorded successfully.');
    }

    /**
     * Update an existing meeting note.
     */
    public function update(Request $request, MeetingNote $note): RedirectResponse|JsonResponse
    {
        $user = Auth::user();
        $meeting = $note->meeting;

        if (!$user->isSuperAdmin() && $note->user_id !== $user->id && $meeting->organizer_id !== $user->id) {
            abort(403, 'Unauthorized to update this meeting note.');
        }

        $validated = $request->validate([
            'agenda' => ['nullable', 'string'],
            'discussion' => ['nullable', 'string'],
            'decisions' => ['nullable', 'string'],
            'action_items' => ['nullable', 'string'],
            'follow_up_date' => ['nullable', 'date'],
            'attachments_text' => ['nullable', 'string'],
        ]);

        $attachments = [];
        if (!empty($validated['attachments_text'])) {
            $lines = preg_split('/[\r\n,]+/', $validated['attachments_text']);
            foreach ($lines as $line) {
                $trimmed = trim($line);
                if ($trimmed) {
                    $attachments[] = [
                        'name' => filter_var($trimmed, FILTER_VALIDATE_URL) ? parse_url($trimmed, PHP_URL_HOST) ?? 'External Link' : $trimmed,
                        'url' => filter_var($trimmed, FILTER_VALIDATE_URL) ? $trimmed : null,
                        'text' => $trimmed,
                    ];
                }
            }
        }

        $oldValues = $note->toArray();

        $note->update([
            'agenda' => $validated['agenda'] ?? null,
            'discussion' => $validated['discussion'] ?? null,
            'decisions' => $validated['decisions'] ?? null,
            'action_items' => $validated['action_items'] ?? null,
            'follow_up_date' => !empty($validated['follow_up_date']) ? Carbon::parse($validated['follow_up_date']) : null,
            'attachments' => $attachments ?: null,
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'meeting_note_updated',
            'auditable_type' => MeetingNote::class,
            'auditable_id' => $note->id,
            'description' => "Meeting notes updated for '{$meeting->title}' by {$user->name}.",
            'old_values' => $oldValues,
            'new_values' => $note->fresh()->toArray(),
        ]);

        if ($request->wantsJson()) {
            return response()->json([
                'success' => true,
                'message' => 'Meeting notes updated.',
                'note' => $note->fresh()->load('author'),
            ]);
        }

        return back()->with('success', 'Meeting notes updated.');
    }

    /**
     * Delete a meeting note.
     */
    public function destroy(MeetingNote $note): RedirectResponse|JsonResponse
    {
        $user = Auth::user();
        $meeting = $note->meeting;

        if (!$user->isSuperAdmin() && $note->user_id !== $user->id && $meeting->organizer_id !== $user->id) {
            abort(403, 'Unauthorized.');
        }

        $note->delete();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'meeting_note_deleted',
            'auditable_type' => MeetingNote::class,
            'auditable_id' => $note->id,
            'description' => "Meeting note removed from '{$meeting->title}' by {$user->name}.",
        ]);

        return back()->with('success', 'Meeting note removed.');
    }
}
