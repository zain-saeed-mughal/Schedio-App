<?php

use App\Http\Controllers\Admin\RegistrationRequestController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

// Guest authentication & registration flow
Route::middleware('guest')->group(function () {
    Route::get('/', [AuthController::class, 'showLogin'])->name('home');
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.post');

    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register'])->name('register.post');
});

// Public Client Booking Routes (Cal.com / Calendly style)
Route::prefix('book')->name('booking.')->group(function () {
    Route::get('/{username}', [\App\Http\Controllers\PublicBookingController::class, 'show'])->name('show');
    Route::get('/{username}/slots', [\App\Http\Controllers\PublicBookingController::class, 'slots'])->name('slots');
    Route::post('/{username}', [\App\Http\Controllers\PublicBookingController::class, 'store'])->middleware('scheduling_guard')->name('store');
    Route::get('/{username}/confirmed/{meeting}', [\App\Http\Controllers\PublicBookingController::class, 'confirmed'])->name('confirmed');
    Route::get('/{username}/export-ical/{meeting}', [\App\Http\Controllers\PublicBookingController::class, 'exportIcal'])->name('export-ical');
});

// Authenticated user routes (guarded with approval status)
Route::middleware(['auth', 'approved', 'scheduling_guard'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    // Meetings Module
    Route::resource('meetings', \App\Http\Controllers\MeetingController::class);
    Route::patch('/meetings/{meeting}/cancel', [\App\Http\Controllers\MeetingController::class, 'cancel'])->name('meetings.cancel');
    Route::post('/meetings/{meeting}/rsvp', [\App\Http\Controllers\MeetingController::class, 'rsvp'])->name('meetings.rsvp');

    // Business Developers (BD) Client & Deal Pipeline Module
    Route::resource('clients', \App\Http\Controllers\ClientController::class);
    Route::patch('/clients/{client}/status', [\App\Http\Controllers\ClientController::class, 'updateStatus'])->name('clients.update-status');
    Route::post('/clients/{client}/schedule-meeting', [\App\Http\Controllers\ClientController::class, 'scheduleMeeting'])->name('clients.schedule-meeting');

    // Availability & Conflict Detection API
    Route::post('/availability/check', [\App\Http\Controllers\AvailabilityController::class, 'check'])->name('availability.check');
    Route::get('/availability/suggestions', [\App\Http\Controllers\AvailabilityController::class, 'suggestions'])->name('availability.suggestions');

    // Calendar Hub
    Route::prefix('calendar')->name('calendar.')->group(function () {
        Route::get('/', [\App\Http\Controllers\CalendarController::class, 'index'])->name('index');
        Route::get('/feed', [\App\Http\Controllers\CalendarController::class, 'feed'])->name('feed');
        Route::post('/', [\App\Http\Controllers\CalendarController::class, 'store'])->name('store');
        Route::patch('/{type}/{id}/time', [\App\Http\Controllers\CalendarController::class, 'updateTime'])->name('update-time');
        Route::delete('/{type}/{id}', [\App\Http\Controllers\CalendarController::class, 'destroy'])->name('destroy');
    });

    // Notifications Module
    Route::prefix('notifications')->name('notifications.')->group(function () {
        Route::get('/', [\App\Http\Controllers\NotificationController::class, 'index'])->name('index');
        Route::get('/feed', [\App\Http\Controllers\NotificationController::class, 'feed'])->name('feed');
        Route::post('/mark-all-read', [\App\Http\Controllers\NotificationController::class, 'markAllAsRead'])->name('mark-all-read');
        Route::patch('/{id}/read', [\App\Http\Controllers\NotificationController::class, 'markAsRead'])->name('mark-read');
        Route::patch('/{id}/unread', [\App\Http\Controllers\NotificationController::class, 'markAsUnread'])->name('mark-unread');
        Route::delete('/{id}', [\App\Http\Controllers\NotificationController::class, 'destroy'])->name('destroy');
        Route::post('/preferences', [\App\Http\Controllers\NotificationController::class, 'updatePreferences'])->name('preferences');
    });


    // Company Events & Training Module
    Route::resource('events', \App\Http\Controllers\EventController::class)->except(['create', 'show', 'edit']);

    // Meeting Suites & Focus Pods Module
    Route::resource('rooms', \App\Http\Controllers\RoomController::class)->except(['create', 'edit']);
    Route::post('/rooms/{room}/availability', [\App\Http\Controllers\RoomController::class, 'checkAvailability'])->name('rooms.check-availability');

    // Meeting Notes & Agendas Module
    Route::post('/meetings/{meeting}/notes', [\App\Http\Controllers\MeetingNoteController::class, 'store'])->name('meetings.notes.store');
    Route::put('/meeting-notes/{note}', [\App\Http\Controllers\MeetingNoteController::class, 'update'])->name('meetings.notes.update');
    Route::delete('/meeting-notes/{note}', [\App\Http\Controllers\MeetingNoteController::class, 'destroy'])->name('meetings.notes.destroy');

    // Tasks & Action Items Module
    Route::post('/tasks', [\App\Http\Controllers\TaskController::class, 'store'])->name('tasks.store');
    Route::patch('/tasks/{task}/status', [\App\Http\Controllers\TaskController::class, 'updateStatus'])->name('tasks.update-status');

    // Super Admin registration request management
    Route::middleware('super_admin')->prefix('admin')->name('admin.')->group(function () {
        Route::get('/registration-requests', [RegistrationRequestController::class, 'index'])->name('registration-requests.index');
        Route::patch('/registration-requests/{user}/approve', [RegistrationRequestController::class, 'approve'])->name('registration-requests.approve');
        Route::patch('/registration-requests/{user}/reject', [RegistrationRequestController::class, 'reject'])->name('registration-requests.reject');
    });
});
