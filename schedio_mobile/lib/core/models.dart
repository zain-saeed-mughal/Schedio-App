typedef Json = Map<String, dynamic>;

Json? asMap(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : null;

Json resultOf(Json response) => asMap(response['data']) ?? response;

int? asInt(Object? value) => switch (value) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v.trim()),
  Map v => asInt(v['id']),
  _ => null,
};

String? nameOf(Object? value) => switch (value) {
  String v when v.isNotEmpty => v,
  Map v => (v['name'] ?? v['company_name'] ?? v['title']) as String?,
  _ => null,
};

List slotsOf(Json response) {
  final list = response['data'] ?? response['slots'];
  return list is List ? list : const [];
}

class Member {
  final int id;
  final String name;
  final String? status;
  const Member(this.id, this.name, [this.status]);
  factory Member.fromJson(Json j) => Member(
    asInt(j['id']) ?? 0,
    (j['name'] ?? j['company_name'] ?? '') as String,
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
    : id = asInt(j['id']) ?? 0,
      name = '${j['name'] ?? ''}',
      email = '${j['email'] ?? ''}',
      role = '${j['role'] ?? ''}',
      timezone = j['timezone'] is String && (j['timezone'] as String).isNotEmpty
          ? j['timezone'] as String
          : 'UTC',
      bookingUrl = j['booking_url'] as String? ?? '',
      bookingUsername = '${j['booking_username'] ?? j['username'] ?? ''}',
      title = j['title'] as String?,
      phone = j['phone'] as String?,
      company = asMap(j['company'])?['name'] as String?,
      department = asMap(j['department'])?['name'] as String?,
      canAdminister = j['can_administer'] == true,
      canManageRooms = j['can_manage_rooms'] == true,
      preferences = NotificationPreferences.fromJson(
        asMap(j['notification_preferences']) ?? const {},
      );
}

class NotificationPreferences {
  final bool inApp, email;
  final Map<String, ({bool inApp, bool email})> categories;
  NotificationPreferences.fromJson(Json j)
    : inApp = asMap(j['channels'])?['in_app'] == true,
      email = asMap(j['channels'])?['email'] == true,
      categories = (asMap(j['categories']) ?? const {}).map(
        (k, v) => MapEntry(k, (
          inApp: asMap(v)?['in_app'] == true,
          email: asMap(v)?['email'] == true,
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

class Record {
  final String id, title, status, description;
  final DateTime? start, end, due, created;
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
  final String? jobTitle, clientName, clientEmail, clientCompany;
  final bool isClientMeeting;
  final int? roomId, departmentId, clientId, assignedTo, meetingId, capacity;
  final List<Member> participants;
  final List<String> amenities;
  final List<String> attachments;
  final String? owner;
  /// Whether the server said the user may manage this record (null: not sent).
  final bool? serverCanManage;
  /// Creator, owner or organiser id, used when the server does not send can_manage.
  final int? creatorId;
  final Module module;
  /// Whether [account] may edit this record. The server's `can_manage` wins
  /// when it is sent; tasks, clients and events currently omit it, so fall
  /// back to the account's role and ownership (the server still enforces it).
  bool canManageAs(Account? account) {
    if (serverCanManage != null) return serverCanManage!;
    if (account == null) return false;
    if (account.canAdminister) return true;
    if (module == Module.rooms) return account.canManageRooms;
    return account.id != 0 && (creatorId == account.id || assignedTo == account.id);
  }

  Record.fromJson(Json j, this.module)
    : id = '${j['id']}',
      title =
          ((module == Module.administration ? j['name'] : null) ??
                  j['title'] ??
                  j['company_name'] ??
                  j['name'] ??
                  asMap(j['data'])?['title'] ??
                  'Meeting note')
              as String,
      status = (j['status'] ?? j['approval_status'] ?? '') as String,
      description =
          (j['description'] ??
                  j['registration_notes'] ??
                  asMap(j['data'])?['message'] ??
                  '')
              as String,
      start = _date(j['start_time']),
      end = _date(j['end_time']),
      due = _date(j['due_date'] ?? j['follow_up_date']),
      created = _date(j['created_at']),
      canManage = j['can_manage'] == true,
      serverCanManage = j['can_manage'] is bool ? j['can_manage'] as bool : null,
      creatorId = asInt(j['creator'] ?? j['created_by'] ?? j['user'] ?? j['organizer'] ?? j['author'] ?? j['user_id']),
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
      agenda = (j['agenda'] ?? j['title']) as String?,
      discussion = (j['discussion'] ?? j['content']) as String?,
      decisions = j['decisions'] as String?,
      actionItems = j['action_items'] is List
          ? (j['action_items'] as List).join('\n')
          : j['action_items'] as String?,
      code = j['code'] as String?,
      role = j['role'] as String?,
      email = j['email'] as String?,
      jobTitle = j['title'] as String?,
      isClientMeeting = asMap(j['metadata'])?['is_client_meeting'] == true,
      clientName = asMap(j['metadata'])?['client_name'] as String?,
      clientEmail = asMap(j['metadata'])?['client_email'] as String?,
      clientCompany = asMap(j['metadata'])?['client_company'] as String?,
      roomId = asInt(j['room_id'] ?? j['room']),
      departmentId = asInt(j['department_id'] ?? j['department']),
      clientId = asInt(j['client_id'] ?? j['client']),
      assignedTo = asInt(j['assigned_to'] ?? j['assignee']),
      meetingId = asInt(j['meeting_id']) ?? asInt(asMap(j['data'])?['meeting_id']),
      capacity = asInt(j['capacity']),
      participants = (j['participants'] as List? ?? [])
          .map((e) => Member.fromJson(e as Json))
          .toList(),
      amenities = [
        for (final a in j['amenities'] is List ? j['amenities'] as List : const [])
          if (a is String ? a : nameOf(a) case final String text) text,
      ],
      attachments = [
        for (final a in j['attachments'] is List ? j['attachments'] as List : const [])
          if (a is String) a else if (asMap(a) case final Json m) '${m['text'] ?? m['url'] ?? m['name'] ?? ''}',
      ],
      owner =
          asMap(
                j['organizer'] ?? j['assignee'] ?? j['assignedTo'] ?? j['assigned_to'] ?? j['author'],
              )?['name']
              as String?;
  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
}

class RecordPage {
  final List<Record> records;
  final int page, lastPage, total;
  RecordPage.fromJson(Json j, Module module)
    : records = (j['data'] as List)
          .map((e) => Record.fromJson(e as Json, module))
          .toList(),
      page = asInt(asMap(j['meta'])?['current_page'] ?? j['current_page']) ?? 1,
      lastPage = asInt(asMap(j['meta'])?['last_page'] ?? j['last_page']) ?? 1,
      total = asInt(asMap(j['meta'])?['total'] ?? j['total']) ?? (j['data'] as List).length;
}

class Dashboard {
  final int today, upcoming, tasks, unread;
  final List<Record> meetings;
  const Dashboard({
    required this.today,
    required this.upcoming,
    required this.tasks,
    required this.unread,
    required this.meetings,
  });
  Dashboard.fromJson(Json j)
    : today = asInt(j['today_meetings']) ?? 0,
      upcoming = asInt(j['upcoming_meetings']) ?? 0,
      tasks = asInt(j['pending_tasks']) ?? 0,
      unread = asInt(j['unread_notifications']) ?? 0,
      meetings = [
        for (final e in j['meetings'] is List ? j['meetings'] as List : const [])
          if (asMap(e) case final Json m) Record.fromJson(m, Module.meetings),
      ];

  Dashboard withUnread(int value) =>
      Dashboard(today: today, upcoming: upcoming, tasks: tasks, unread: value, meetings: meetings);

  factory Dashboard.parse(Json response) {
    final j = resultOf(response);
    final metrics = asMap(j['metrics']);
    if (metrics == null) return Dashboard.fromJson(j);
    int count(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    List<Json> rows(Object? v) => [
      for (final item in v is List ? v : const [])
        if (asMap(item) case final Json m) m,
    ];
    final seen = <Object?>{};
    return Dashboard(
      today: count(metrics['today_meetings_count'] ?? metrics['today_meetings']),
      upcoming: count(metrics['upcoming_meetings']),
      tasks: count(metrics['pending_tasks']),
      unread: count(metrics['unread_notifications']),
      meetings: [
        for (final m in [...rows(j['today_meetings']), ...rows(j['upcoming_meetings'])])
          if (seen.add(m['id'])) Record.fromJson(m, Module.meetings),
      ].take(8).toList(),
    );
  }
}

class Lookups {
  final List<Member> users, departments, rooms, clients;
  final List<String> taskStatuses;
  final bool hasClients;
  Lookups.fromJson(Json j)
    : users = _members(j['users']),
      departments = _members(j['departments']),
      rooms = _members(j['rooms']),
      clients = _members(j['clients']),
      hasClients = j['clients'] is List,
      taskStatuses = [
        for (final s in j['task_statuses'] is List ? j['task_statuses'] as List : const [])
          if (s is String) s else if (asMap(s)?['key'] case final String key) key,
      ];
  static List<Member> _members(dynamic j) => [
    for (final e in j is List ? j : const [])
      if (asMap(e) case final Json m when m['id'] is int && (m['name'] ?? m['company_name']) is String)
        Member.fromJson(m),
  ];
}

class CalendarEntry {
  final String title, id;
  final Module module;
  final DateTime start, end;
  CalendarEntry.fromJson(Json j)
    : title = '${j['title'] ?? 'Untitled'}',
      id = '${j['id']}',
      module = j['entity_type'] == 'meeting' ? Module.meetings : Module.events,
      start = DateTime.parse(j['start_time'] as String),
      end =
          DateTime.tryParse('${j['end_time']}') ??
          DateTime.parse(j['start_time'] as String).add(const Duration(hours: 1));
}

class BookingProfile {
  final String name, headline, bio, timezone;
  final List<int> durations;
  final int defaultDuration;
  BookingProfile._(this.name, this.headline, this.bio, this.timezone, this.durations, this.defaultDuration);

  factory BookingProfile.fromJson(Json j) {
    final durations = [
      for (final d in j['durations'] is List ? j['durations'] as List : const [])
        if (asInt(d) case final int minutes when minutes > 0) minutes,
    ];
    if (durations.isEmpty) durations.add(30);
    final preferred = asInt(j['default_duration']);
    return BookingProfile._(
      (j['name'] as String?) ?? 'Schedio host',
      (j['booking_headline'] ?? j['headline']) as String? ?? 'Let’s find a time',
      (j['booking_bio'] ?? j['bio']) as String? ?? '',
      (j['timezone'] as String?) ?? 'UTC',
      durations,
      durations.contains(preferred) ? preferred! : durations.first,
    );
  }
}

class Slot {
  final DateTime start, end;
  Slot.fromJson(Json j)
    : start = DateTime.parse(j['start_time'] as String),
      end = DateTime.parse(j['end_time'] as String);
}

/// Formats [t] as wall-clock time with its own UTC offset (no "Z").
String isoWithOffset(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final o = t.timeZoneOffset;
  final m = o.inMinutes.abs();
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
      '${o.isNegative ? '-' : '+'}${two(m ~/ 60)}:${two(m % 60)}';
}
