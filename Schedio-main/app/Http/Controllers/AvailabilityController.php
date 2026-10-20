<?php

namespace App\Http\Controllers;

use App\Services\ConflictDetectionService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AvailabilityController extends Controller
{
    public function __construct(
        protected ConflictDetectionService $conflictService
    ) {}

    /**
     * Check real-time conflicts for selected participants and meeting room.
     */
    public function check(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after:start_time'],
            'room_id' => ['nullable', 'exists:rooms,id'],
            'participant_ids' => ['nullable', 'array'],
            'participant_ids.*' => ['exists:users,id'],
            'exclude_meeting_id' => ['nullable', 'exists:meetings,id'],
        ]);

        $start = Carbon::parse($validated['start_time']);
        $end = Carbon::parse($validated['end_time']);
        $roomId = !empty($validated['room_id']) ? (int) $validated['room_id'] : null;
        $participantIds = $validated['participant_ids'] ?? [];
        $excludeMeetingId = !empty($validated['exclude_meeting_id']) ? (int) $validated['exclude_meeting_id'] : null;

        $result = $this->conflictService->checkAvailability(
            $start,
            $end,
            $roomId,
            $participantIds,
            $excludeMeetingId
        );

        return response()->json($result);
    }

    /**
     * Get smart time slot suggestions for participants and room.
     */
    public function suggestions(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'date' => ['required', 'date'],
            'duration_minutes' => ['nullable', 'integer', 'min:15', 'max:480'],
            'room_id' => ['nullable', 'exists:rooms,id'],
            'participant_ids' => ['nullable', 'array'],
            'participant_ids.*' => ['exists:users,id'],
            'exclude_meeting_id' => ['nullable', 'exists:meetings,id'],
        ]);

        $date = Carbon::parse($validated['date']);
        $duration = (int) ($validated['duration_minutes'] ?? 60);
        $roomId = !empty($validated['room_id']) ? (int) $validated['room_id'] : null;
        $participantIds = $validated['participant_ids'] ?? [];
        $excludeMeetingId = !empty($validated['exclude_meeting_id']) ? (int) $validated['exclude_meeting_id'] : null;

        $suggestions = $this->conflictService->suggestAvailableSlots(
            $date,
            $duration,
            $roomId,
            $participantIds,
            $excludeMeetingId
        );

        return response()->json([
            'slots' => $suggestions,
            'count' => count($suggestions),
        ]);
    }
}
