<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class MeetingRequest extends FormRequest
{
    public function authorize(): bool { return $this->user() !== null; }
    public function rules(): array
    {
        return [
            'title' => 'required|string|max:255', 'description' => 'nullable|string|max:20000',
            'start_time' => ['required', 'date', 'regex:/(Z|[+-]\d{2}:\d{2})$/'],
            'end_time' => ['required', 'date', 'after:start_time', 'regex:/(Z|[+-]\d{2}:\d{2})$/'],
            'timezone' => 'required|timezone',
            'type' => ['required', Rule::in(['in_person', 'virtual', 'hybrid'])],
            'meeting_link' => 'nullable|url:http,https|max:255', 'location' => 'nullable|string|max:255',
            'is_private' => 'boolean', 'is_client_meeting' => 'boolean',
            'save_as_client' => ['boolean', Rule::prohibitedIf(fn () => (bool) $this->route('id') || $this->filled('client_id'))],
            'campaign' => 'nullable|string|max:150',
            'client_name' => 'nullable|string|max:150', 'client_email' => 'nullable|email|max:150',
            'client_company' => 'required_if:save_as_client,true|nullable|string|max:150', 'department_id' => 'nullable|integer',
            'room_id' => 'nullable|integer', 'client_id' => 'nullable|integer',
            'participant_ids' => 'nullable|array|max:100', 'participant_ids.*' => 'integer|distinct',
            'reminder_minutes' => ['nullable', 'integer', Rule::in([0, 5, 10, 15, 30, 60, 1440])],
            'recurrence_frequency' => ['nullable', Rule::in(['none', 'daily', 'weekly', 'biweekly', 'monthly'])],
        ];
    }
}
