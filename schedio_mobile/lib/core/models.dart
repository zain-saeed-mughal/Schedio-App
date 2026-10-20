typedef Json = Map<String, dynamic>;

class Member {
  final int id;
  final String name;
  final String? status;
  const Member(this.id, this.name, [this.status]);
  factory Member.fromJson(Json j) => Member(
    j['id'] as int,
    (j['name'] ?? j['company_name']) as String,
    j['status'] as String?,
  );
}

class Account {
  final int id;
  final String name, email, role, timezone, bookingUrl, bookingUsername;
  final String? title, phone, company, department;
  final bool canAdminister, canManageRooms;
  final NotificationPreferences preferences;
  Account.fromJson(Json j)
    : id = j['id'] as int,
      name = j['name'] as String,
      email = j['email'] as String,
      role = j['role'] as String,
      timezone = j['timezone'] as String? ?? 'UTC',
      bookingUrl = j['booking_url'] as String,
      bookingUsername = j['booking_username'] as String,
      title = j['title'] as String?,
      phone = j['phone'] as String?,
      company = (j['company'] as Json?)?['name'] as String?,
      department = (j['department'] as Json?)?['name'] as String?,
      canAdminister = j['can_administer'] == true,
      canManageRooms = j['can_manage_rooms'] == true,
      preferences = NotificationPreferences.fromJson(
        j['notification_preferences'] as Json,
      );
}

class NotificationPreferences {
  final bool inApp, email;
  final Map<String, ({bool inApp, bool email})> categories;
  NotificationPreferences.fromJson(Json j)
    : inApp = (j['channels'] as Json)['in_app'] == true,
      email = (j['channels'] as Json)['email'] == true,
      categories = (j['categories'] as Json).map(
        (k, v) => MapEntry(k, (
          inApp: (v as Json)['in_app'] == true,
          email: v['email'] == true,
        )),
      );
}

enum Module {
  meetings('Meetings', 'meetings'),
  tasks('Tasks', 'tasks'),
  clients('Clients', 'clients'),
  rooms('Meeting rooms', 'rooms'),
  events('Company events', 'events'),
  notes('Meeting notes', 'meeting-notes'),
  notifications('Notifications', 'notifications'),
  administration('Registration requests', 'admin/registration-requests');

  final String label, path;
  const Module(this.label, this.path);
}

/// Decodes transport data at the repository boundary; screens use typed fields.
class Record {
  final String id, title, status, description;
  final DateTime? start, end, due;
  final bool canManage,
      canRsvp,
      isPrivate,
      isActive,
      isCompanyWide,
      isAllDay,
      isRead;
  final String? timezone, type, location, meetingLink, priority, category;
  final String? contactName,
      contactEmail,
      contactPhone,
      contactRole,
      campaign,
      progress,
      notes,
      dealValue;
  final String? agenda, discussion, decisions, actionItems, code, role, email;
  final int? roomId, departmentId, clientId, assignedTo, meetingId, capacity;
  final List<Member> participants;
  final List<String> amenities;
  final List<String> attachments;
  final String? owner;
  final Module module;
  Record.fromJson(Json j, this.module)
    : id = '${j['id']}',
      title =
          (j['title'] ??
                  j['company_name'] ??
                  j['name'] ??
                  (j['data'] as Json?)?['title'] ??
                  'Meeting note')
              as String,
      status = (j['status'] ?? j['approval_status'] ?? '') as String,
      description =
          (j['description'] ??
                  j['registration_notes'] ??
                  (j['data'] as Json?)?['message'] ??
                  '')
              as String,
      start = _date(j['start_time']),
      end = _date(j['end_time']),
      due = _date(j['due_date'] ?? j['follow_up_date']),
      canManage = j['can_manage'] == true,
      canRsvp = j['can_rsvp'] == true,
      isPrivate = j['is_private'] == true,
      isActive = j['is_active'] != false,
      isCompanyWide = j['is_company_wide'] == true,
      isAllDay = j['is_all_day'] == true,
      isRead = j['read_at'] != null,
      timezone = j['timezone'] as String?,
      type = j['type'] as String?,
      location = j['location'] as String?,
      meetingLink = j['meeting_link'] as String?,
      priority = j['priority'] as String?,
      category = j['category'] as String?,
      contactName = j['contact_name'] as String?,
      contactEmail = j['contact_email'] as String?,
      contactPhone = j['contact_phone'] as String?,
      contactRole = j['contact_role'] as String?,
      campaign = j['campaign'] as String?,
      progress = j['progress'] as String?,
      notes = j['notes'] as String?,
      dealValue = j['deal_value']?.toString(),
      agenda = j['agenda'] as String?,
      discussion = j['discussion'] as String?,
      decisions = j['decisions'] as String?,
      actionItems = j['action_items'] as String?,
      code = j['code'] as String?,
      role = j['role'] as String?,
      email = j['email'] as String?,
      roomId = j['room_id'] as int?,
      departmentId = j['department_id'] as int?,
      clientId = j['client_id'] as int?,
      assignedTo = j['assigned_to'] as int?,
      meetingId =
          j['meeting_id'] as int? ??
          (j['data'] as Json?)?['meeting_id'] as int?,
      capacity = j['capacity'] as int?,
      participants = (j['participants'] as List? ?? [])
          .map((e) => Member.fromJson(e as Json))
          .toList(),
      amenities = (j['amenities'] as List? ?? []).cast<String>(),
      attachments = (j['attachments'] as List? ?? [])
          .map(
            (a) =>
                ((a as Json)['text'] ?? a['url'] ?? a['name'] ?? '').toString(),
          )
          .toList(),
      owner =
          ((j['organizer'] ?? j['assignee'] ?? j['assignedTo'] ?? j['author'])
                  as Json?)?['name']
              as String?;
  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
}

class RecordPage {
  final List<Record> records;
  final int page, lastPage;
  RecordPage.fromJson(Json j, Module module)
    : records = (j['data'] as List)
          .map((e) => Record.fromJson(e as Json, module))
          .toList(),
      page =
          ((j['meta'] as Json?)?['current_page'] ?? j['current_page'] ?? 1)
              as int,
      lastPage =
          ((j['meta'] as Json?)?['last_page'] ?? j['last_page'] ?? 1) as int;
}

class Dashboard {
  final int today, upcoming, tasks, unread;
  final List<Record> meetings;
  Dashboard.fromJson(Json j)
    : today = j['today_meetings'] as int,
      upcoming = j['upcoming_meetings'] as int,
      tasks = j['pending_tasks'] as int,
      unread = j['unread_notifications'] as int,
      meetings = (j['meetings'] as List)
          .map((e) => Record.fromJson(e as Json, Module.meetings))
          .toList();
}

class Lookups {
  final List<Member> users, departments, rooms, clients;
  Lookups.fromJson(Json j)
    : users = _members(j['users']),
      departments = _members(j['departments']),
      rooms = _members(j['rooms']),
      clients = _members(j['clients']);
  static List<Member> _members(dynamic j) =>
      (j as List).map((e) => Member.fromJson(e as Json)).toList();
}

class CalendarEntry {
  final String title, id;
  final Module module;
  final DateTime start, end;
  CalendarEntry.fromJson(Json j)
    : title = j['title'] as String,
      id = '${j['id']}',
      module = j['entity_type'] == 'meeting' ? Module.meetings : Module.events,
      start = DateTime.parse(j['start_time'] as String),
      end = DateTime.parse(j['end_time'] as String);
}

class BookingProfile {
  final String name, headline, bio, timezone;
  final List<int> durations;
  BookingProfile.fromJson(Json j)
    : name = j['name'] as String,
      headline = j['headline'] as String? ?? 'Let’s find a time',
      bio = j['bio'] as String? ?? '',
      timezone = j['timezone'] as String,
      durations = (j['durations'] as List).cast<int>();
}

class Slot {
  final DateTime start, end;
  Slot.fromJson(Json j)
    : start = DateTime.parse(j['start_time'] as String),
      end = DateTime.parse(j['end_time'] as String);
}
