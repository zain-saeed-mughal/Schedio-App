<?php

use App\Http\Controllers\Api\{ActivityController, AuthController, BookingController, MeetingController, WorkspaceController};
use App\Http\Middleware\MobileAccess;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware('throttle:120,1')->group(function () {
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:6,1');
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:6,1');
    Route::get('auth/registration-options', [AuthController::class, 'options']);
    Route::get('public/booking/{username}', [BookingController::class, 'show']);
    Route::get('public/booking-confirmations/{meeting}/ical', [BookingController::class, 'export'])
        ->middleware('signed')->name('api.booking.ical');
    Route::get('public/booking/{username}/slots', [BookingController::class, 'slots']);
    Route::post('public/booking/{username}', [BookingController::class, 'store'])->middleware(['throttle:6,1', 'scheduling_guard']);
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::middleware([MobileAccess::class, 'scheduling_guard'])->group(function () {
            Route::get('auth/me', [AuthController::class, 'me']);
            Route::get('dashboard', [WorkspaceController::class, 'dashboard']);
            Route::get('lookups', [WorkspaceController::class, 'lookups']);
            Route::get('clients/{id}/meetings', [WorkspaceController::class, 'clientMeetings'])->whereNumber('id');
            Route::get('meetings', [MeetingController::class, 'index']);
            Route::post('meetings', [MeetingController::class, 'save']);
            Route::get('meetings/{id}', [MeetingController::class, 'show'])->whereNumber('id');
            Route::put('meetings/{id}', [MeetingController::class, 'save'])->whereNumber('id');
            Route::delete('meetings/{id}', [MeetingController::class, 'action'])->defaults('action', 'delete')->whereNumber('id');
            Route::patch('meetings/{id}/cancel', [MeetingController::class, 'action'])->defaults('action', 'cancel')->whereNumber('id');
            Route::post('meetings/{id}/rsvp', [MeetingController::class, 'action'])->defaults('action', 'rsvp')->whereNumber('id');
            Route::post('availability/check', [MeetingController::class, 'availability']);
            Route::get('availability/suggestions', [MeetingController::class, 'suggestions']);
            Route::get('calendar/feed', [ActivityController::class, 'calendar']);
            Route::match(['GET', 'POST'], 'meetings/{id}/notes', [WorkspaceController::class, 'notes'])->whereNumber('id');
            Route::match(['GET', 'PUT', 'DELETE'], 'meeting-notes/{id}', [WorkspaceController::class, 'note'])->whereNumber('id');
            Route::get('notifications', [ActivityController::class, 'notifications']);
            Route::post('notifications/mark-all-read', [ActivityController::class, 'markAllRead']);
            Route::post('notifications/preferences', [ActivityController::class, 'preferences']);
            Route::patch('notifications/{id}/{action}', [ActivityController::class, 'notification'])->whereIn('action', ['read', 'unread']);
            Route::delete('notifications/{id}', [ActivityController::class, 'notification']);
            Route::get('admin/registration-requests', [ActivityController::class, 'requests']);
            Route::patch('admin/registration-requests/{id}/{action}', [ActivityController::class, 'decide'])
                ->whereNumber('id')->whereIn('action', ['approve', 'reject']);
            Route::get('{module}', [WorkspaceController::class, 'index'])->whereIn('module', array_keys(WorkspaceController::MODULES));
            Route::get('{module}/{id}', [WorkspaceController::class, 'show'])->whereIn('module', array_keys(WorkspaceController::MODULES))->whereNumber('id');
            Route::post('{module}', [WorkspaceController::class, 'mutate'])->whereIn('module', array_keys(WorkspaceController::MODULES));
            Route::match(['PUT', 'DELETE'], '{module}/{id}', [WorkspaceController::class, 'mutate'])
                ->whereIn('module', ['clients', 'rooms', 'events'])->whereNumber('id');
            Route::patch('{module}/{id}/status', [WorkspaceController::class, 'mutate'])
                ->whereIn('module', ['clients', 'tasks'])->whereNumber('id')->defaults('action', 'status');
        });
    });
});
