<?php

namespace App\Services;

use App\Models\Event;
use App\Models\Meeting;
use App\Models\Room;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class ConflictDetectionService
{
    /**
     * Check comprehensive availability for a room and list of participants within a time window.
     *
     * @param Carbon $start
     * @param Carbon $end
     * @param int|null $roomId
     * @param array<int> $participantIds
     * @param int|null $excludeMeetingId
     * @return array
     */
    public function checkAvailability(
        Carbon $start,
        Carbon $end,
        ?int $roomId = null,
        array $participantIds = [],
        ?int $excludeMeetingId = null
    ): array {
        $roomConflict = null;
        if ($roomId) {
            $roomConflict = $this->checkRoomConflict($roomId, $start, $end, $excludeMeetingId);
        }

        $participantsAvailability = [];
        if (!empty($participantIds)) {
            $participantsAvailability = $this->checkParticipantsAvailability($participantIds, $start, $end, $excludeMeetingId);
        }

        $hasConflicts = ($roomConflict !== null) || collect($participantsAvailability)->contains('status', 'conflict');

        return [
            'has_conflicts' => $hasConflicts,
            'room' => $roomConflict ? [
                'status' => 'conflict',
                'room_id' => $roomId,
                'conflict' => $roomConflict,
            ] : ($roomId ? ['status' => 'available', 'room_id' => $roomId] : null),
            'participants' => $participantsAvailability,
        ];
    }

    /**
     * Check if a specific room has a collision in the given time window.
     */
    public function checkRoomConflict(int $roomId, Carbon $start, Carbon $end, ?int $excludeMeetingId = null): ?array
    {
        $query = Meeting::where('room_id', $roomId)
            ->where('status', '!=', 'cancelled')
            ->where(function ($q) use ($start, $end) {
                $q->where('start_time', '<', $end)
                  ->where('end_time', '>', $start);
            });

        if ($excludeMeetingId) {
            $query->where('id', '!=', $excludeMeetingId);
        }

        $conflictingMeeting = $query->with('organizer')->first();

        if (!$conflictingMeeting) {
            return null;
        }

        return [
            'meeting_id' => $conflictingMeeting->id,
            'title' => $conflictingMeeting->title,
            'start_time' => $conflictingMeeting->start_time->toIso8601String(),
            'end_time' => $conflictingMeeting->end_time->toIso8601String(),
            'organizer' => $conflictingMeeting->organizer ? $conflictingMeeting->organizer->name : 'Unknown',
        ];
    }

    /**
     * Check each participant's schedule (both meetings and events) for collisions.
     */
    public function checkParticipantsAvailability(
        array $participantIds,
        Carbon $start,
        Carbon $end,
        ?int $excludeMeetingId = null
    ): array {
        $users = User::whereIn('id', $participantIds)->get()->keyBy('id');
        $results = [];

        foreach ($participantIds as $userId) {
            $user = $users->get($userId);
            if (!$user) {
                continue;
            }

            // 1. Check Meetings (where user is organizer or accepted/pending participant)
            $meetingConflictQuery = Meeting::where('status', '!=', 'cancelled')
                ->where(function ($q) use ($start, $end) {
                    $q->where('start_time', '<', $end)
                      ->where('end_time', '>', $start);
                })
                ->where(function ($q) use ($userId) {
                    $q->where('organizer_id', $userId)
                      ->orWhereHas('participants', function ($p) use ($userId) {
                          $p->where('users.id', $userId)
                            ->whereIn('meeting_participants.status', ['accepted', 'pending']);
                      });
                });

            if ($excludeMeetingId) {
                $meetingConflictQuery->where('id', '!=', $excludeMeetingId);
            }

            $conflictMeeting = $meetingConflictQuery->first();

            // 2. Check Personal / Department Events
            $conflictEvent = null;
            if (!$conflictMeeting) {
                $conflictEvent = Event::where(function ($q) use ($start, $end) {
                        $q->where('start_time', '<', $end)
                          ->where('end_time', '>', $start);
                    })
                    ->where(function ($q) use ($user) {
                        $q->where('user_id', $user->id)
                          ->orWhere('department_id', $user->department_id)
                          ->orWhere('is_company_wide', true);
                    })
                    ->first();
            }

            if ($conflictMeeting) {
                $results[] = [
                    'user_id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'status' => 'conflict',
                    'reason' => 'Meeting: ' . $conflictMeeting->title,
                    'conflict_time' => $conflictMeeting->start_time->format('h:i A') . ' - ' . $conflictMeeting->end_time->format('h:i A'),
                ];
            } elseif ($conflictEvent) {
                $results[] = [
                    'user_id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'status' => 'busy',
                    'reason' => 'Event: ' . $conflictEvent->title,
                    'conflict_time' => $conflictEvent->start_time->format('h:i A') . ' - ' . $conflictEvent->end_time->format('h:i A'),
                ];
            } else {
                $results[] = [
                    'user_id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'status' => 'available',
                    'reason' => 'Available',
                    'conflict_time' => null,
                ];
            }
        }

        return $results;
    }

    /**
     * Smart Time Slot Suggestions:
     * Find 3 to 5 conflict-free time slots on the requested date for given participants and optional room.
     *
     * @param Carbon $targetDate
     * @param int $durationMinutes (e.g. 30, 45, 60)
     * @param int|null $roomId
     * @param array<int> $participantIds
     * @param int|null $excludeMeetingId
     * @return array
     */
    public function suggestAvailableSlots(
        Carbon $targetDate,
        int $durationMinutes = 60,
        ?int $roomId = null,
        array $participantIds = [],
        ?int $excludeMeetingId = null
    ): array {
        $slots = [];
        // Workday standard hours: 09:00 to 18:00
        $workdayStart = $targetDate->copy()->setTime(9, 0, 0);
        $workdayEnd = $targetDate->copy()->setTime(18, 0, 0);

        $cursor = $workdayStart->copy();

        while ($cursor->copy()->addMinutes($durationMinutes)->lte($workdayEnd)) {
            $slotStart = $cursor->copy();
            $slotEnd = $cursor->copy()->addMinutes($durationMinutes);

            $check = $this->checkAvailability($slotStart, $slotEnd, $roomId, $participantIds, $excludeMeetingId);

            if (!$check['has_conflicts']) {
                $slots[] = [
                    'start_time' => $slotStart->toIso8601String(),
                    'end_time' => $slotEnd->toIso8601String(),
                    'formatted_start' => $slotStart->format('h:i A'),
                    'formatted_end' => $slotEnd->format('h:i A'),
                    'date' => $slotStart->format('D, M d'),
                ];

                if (count($slots) >= 5) {
                    break;
                }
            }

            // Step by 30-minute intervals
            $cursor->addMinutes(30);
        }

        return $slots;
    }
}
