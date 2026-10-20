import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

const clientStatuses = [
  'discovery',
  'scheduled',
  'paperwork_onboarding',
  'onboarded',
  'deadend',
  'pause',
];
const taskStatuses = [
  'todo',
  'in_progress',
  'review',
  'completed',
  'cancelled',
];
const eventCategories = [
  'company_holiday',
  'deadline',
  'training',
  'milestone',
  'out_of_office',
  'general',
];

class Editor extends ConsumerStatefulWidget {
  final Module module;
  final Record? record;
  final String? meetingId;
  final int? clientId;
  const Editor({
    super.key,
    required this.module,
    this.record,
    this.meetingId,
    this.clientId,
  });
  @override
  ConsumerState<Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<Editor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  final participantIds = <int>{};
  DateTime? start, end, due;
  bool busy = false;
  String? error;
  String get zone => ref.read(authProvider).value?.timezone ?? 'UTC';
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    start = r?.start;
    end = r?.end;
    due = r?.due;
    values.addAll({
      'type': r?.type ?? 'virtual',
      'status': r?.status ?? 'discovery',
      'priority': r?.priority ?? 'medium',
      'category': r?.category ?? 'general',
      'room_id': r?.roomId,
      'department_id': r?.departmentId,
      'client_id': r?.clientId ?? widget.clientId,
      'assigned_to': r?.assignedTo,
      'is_private': r?.isPrivate ?? false,
      'is_client_meeting': r?.isClientMeeting ?? false,
      'save_as_client': false,
      'is_active': r?.isActive ?? true,
      'is_company_wide': r?.isCompanyWide ?? false,
      'is_all_day': r?.isAllDay ?? false,
      'reminder_minutes': 15,
      'recurrence_frequency': 'none',
    });
    participantIds.addAll(r?.participants.map((p) => p.id) ?? []);
    final initial = {
      'title': r?.title,
      'client_name': r?.clientName,
      'client_email': r?.clientEmail,
      'client_company': r?.clientCompany,
      'description': r?.description,
      'location': r?.location,
      'meeting_link': r?.meetingLink,
      'company_name': r?.title,
      'contact_name': r?.contactName,
      'contact_email': r?.contactEmail,
      'contact_phone': r?.contactPhone,
      'contact_role': r?.contactRole,
      'campaign': r?.campaign,
      'progress': r?.progress,
      'notes': r?.notes,
      'deal_value': r?.dealValue,
      'name': r?.title,
      'code': r?.code,
      'capacity': r?.capacity?.toString(),
      'amenities_text': r?.amenities.join(', '),
      'attachments_text': r?.attachments.join('\n'),
      'agenda': r?.agenda,
      'discussion': r?.discussion,
      'decisions': r?.decisions,
      'action_items': r?.actionItems,
    };
    for (final e in initial.entries) {
      fields[e.key] = TextEditingController(text: e.value ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget text(
    String key,
    String title, {
    bool required = false,
    int lines = 1,
    bool number = false,
  }) {
    final controller = fields.putIfAbsent(key, TextEditingController.new);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: title),
        validator: (v) => required && (v == null || v.trim().isEmpty)
            ? '$title is required'
            : null,
      ),
    );
  }

  Widget choices(String key, String title, List<String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: options.contains(values[key])
          ? values[key] as String
          : options.first,
      decoration: InputDecoration(labelText: title),
      isExpanded: true,
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(label(v))))
          .toList(),
      onChanged: (v) => values[key] = v,
    ),
  );
  Widget lookup(String key, String title, List<Member> options) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<int>(
      initialValue: options.any((m) => m.id == values[key])
          ? values[key] as int?
          : null,
      decoration: InputDecoration(labelText: title),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('None')),
        ...options.map(
          (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
        ),
      ],
      onChanged: (v) => values[key] = v,
    ),
  );
  Widget toggle(String key, String title) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: values[key] == true,
    onChanged: (v) => setState(() => values[key] = v),
  );
  Future<void> pick(String kind) async {
    final old = kind == 'start'
        ? start
        : kind == 'end'
        ? end
        : due;
    final local = tz.TZDateTime.from(old ?? DateTime.now(), locationFor(zone));
    final day = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;
    final result = tz.TZDateTime(
      locationFor(zone),
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (result.hour != time.hour || result.minute != time.minute) {
      setState(
        () => error = 'That local time does not exist due to daylight saving. Choose another time.',
      );
      return;
    }
    setState(() {
      if (kind == 'start') {
        start = result.toUtc();
        end ??= start!.add(const Duration(hours: 1));
      } else if (kind == 'end') {
        end = result.toUtc();
      } else {
        due = result.toUtc();
      }
    });
  }

  Widget timeTile(String title, String kind, DateTime? value) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(
        value == null ? 'Choose date and time · $zone' : dateLabel(value, zone),
      ),
      trailing: const Icon(Icons.schedule),
      onTap: () => pick(kind),
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final m = widget.module;
    if (m == Module.meetings &&
        values['is_client_meeting'] == true &&
        values['save_as_client'] == true &&
        values['client_id'] != null) {
      setState(
        () => error = 'Choose either an existing client or save a new client.',
      );
      return;
    }
    if ([Module.meetings, Module.events].contains(m) &&
        (start == null || end == null || !end!.isAfter(start!))) {
      setState(() => error = 'Choose an end time after the start time.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final allowed = switch (m) {
      Module.meetings => [
        'title',
        'description',
        'location',
        'meeting_link',
        if (values['is_client_meeting'] == true) ...[
          'client_name',
          'client_email',
          'client_company',
          'campaign',
        ],
      ],
      Module.tasks => ['title', 'description'],
      Module.clients => [
        'company_name',
        'contact_name',
        'contact_email',
        'contact_phone',
        'contact_role',
        'campaign',
        'progress',
        'notes',
        'deal_value',
      ],
      Module.rooms => [
        'name',
        'code',
        'location',
        'capacity',
        'amenities_text',
      ],
      Module.events => ['title', 'description', 'location'],
      Module.notes => [
        'agenda',
        'discussion',
        'decisions',
        'action_items',
        'attachments_text',
      ],
      _ => <String>[],
    };
    final payload = <String, dynamic>{
      for (final key in allowed)
        key: fields[key]?.text.trim().isEmpty != false
            ? null
            : fields[key]!.text.trim(),
    };
    final keys = switch (m) {
      Module.meetings => [
        'type',
        'department_id',
        'room_id',
        'client_id',
        'is_private',
        'is_client_meeting',
        'reminder_minutes',
        'recurrence_frequency',
      ],
      Module.tasks => ['priority', 'assigned_to', 'department_id'],
      Module.clients => ['status', 'assigned_to'],
      Module.rooms => ['is_active'],
      Module.events => [
        'category',
        'department_id',
        'is_all_day',
        'is_company_wide',
      ],
      _ => <String>[],
    };
    for (final k in keys) {
      payload[k] = values[k];
    }
    if (m == Module.meetings) {
      if (widget.record == null &&
          values['is_client_meeting'] == true &&
          values['client_id'] == null &&
          values['save_as_client'] == true) {
        payload['save_as_client'] = true;
      }
      payload['participant_ids'] = participantIds.toList();
      payload['timezone'] = zone;
    }
    if ([Module.meetings, Module.events].contains(m)) {
      payload['start_time'] = start!.toUtc().toIso8601String();
      payload['end_time'] = end!.toUtc().toIso8601String();
    }
    if (m == Module.tasks) {
      payload['due_date'] = due?.toUtc().toIso8601String();
      payload['meeting_id'] = widget.meetingId;
    }
    if (m == Module.notes) {
      payload['follow_up_date'] = due?.toUtc().toIso8601String();
    }
    var path = m.path;
    if (widget.record != null) {
      path += '/${widget.record!.id}';
    } else if (m == Module.notes) {
      path = 'meetings/${widget.meetingId}/notes';
    }
    try {
      await ref
          .read(apiProvider)
          .request(
            path,
            method: widget.record == null ? 'POST' : 'PUT',
            data: payload,
          );
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.record == null ? 'New' : 'Edit'} ${m.label.toLowerCase()}',
        ),
      ),
      body: AsyncBody(
        value: ref.watch(lookupsProvider),
        retry: () => ref.invalidate(lookupsProvider),
        builder: (l) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if ([
                    Module.meetings,
                    Module.tasks,
                    Module.events,
                  ].contains(m)) ...[
                    text('title', 'Title', required: true),
                    text('description', 'Description', lines: 3),
                  ],
                  if ([Module.meetings, Module.events].contains(m)) ...[
                    timeTile('Starts', 'start', start),
                    timeTile('Ends', 'end', end),
                    const SizedBox(height: 16),
                    lookup('department_id', 'Department', l.departments),
                    text('location', 'Location'),
                  ],
                  if (m == Module.meetings) ...[
                    choices('type', 'Meeting type', [
                      'virtual',
                      'in_person',
                      'hybrid',
                    ]),
                    if (widget.record == null) ...[
                      choices('recurrence_frequency', 'Recurrence preference', [
                        'none',
                        'daily',
                        'weekly',
                        'biweekly',
                        'monthly',
                      ]),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'This records a recurrence preference. Additional meeting instances are not scheduled automatically.',
                        ),
                      ),
                    ],
                    text('meeting_link', 'Meeting link'),
                    lookup('room_id', 'Room', l.rooms),
                    lookup('client_id', 'Client', l.clients),
                    toggle('is_client_meeting', 'External guest'),
                    if (values['is_client_meeting'] == true) ...[
                      text('client_name', 'Guest name'),
                      text('client_email', 'Guest email'),
                      text(
                        'client_company',
                        'Guest company',
                        required: values['save_as_client'] == true,
                      ),
                      if (widget.record == null) ...[
                        toggle('save_as_client', 'Save guest as a new client'),
                        if (values['save_as_client'] == true) ...[
                          const Text(
                            'Leave Client as None to create a new client with this meeting.',
                          ),
                          text('campaign', 'Campaign'),
                        ],
                      ],
                    ],
                    toggle('is_private', 'Private meeting'),
                    const Text('Participants'),
                    ...l.users.map(
                      (u) => CheckboxListTile(
                        title: Text(u.name),
                        value: participantIds.contains(u.id),
                        onChanged: (v) => setState(() {
                          v == true
                              ? participantIds.add(u.id)
                              : participantIds.remove(u.id);
                        }),
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: values['reminder_minutes'] as int,
                      decoration: const InputDecoration(labelText: 'Reminder'),
                      items: [0, 5, 10, 15, 30, 60, 1440]
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                n == 0 ? 'None' : '$n minutes before',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => values['reminder_minutes'] = v,
                    ),
                  ],
                  if (m == Module.tasks) ...[
                    choices('priority', 'Priority', [
                      'low',
                      'medium',
                      'high',
                      'urgent',
                    ]),
                    lookup('assigned_to', 'Assigned to', l.users),
                    lookup('department_id', 'Department', l.departments),
                    timeTile('Due date (optional)', 'due', due),
                  ],
                  if (m == Module.clients) ...[
                    text('company_name', 'Company name', required: true),
                    text('contact_name', 'Contact name', required: true),
                    text('contact_email', 'Contact email'),
                    text('contact_phone', 'Contact phone'),
                    text('contact_role', 'Contact role'),
                    text('campaign', 'Campaign'),
                    choices('status', 'Pipeline stage', clientStatuses),
                    text('deal_value', 'Deal value', number: true),
                    if (ref.read(authProvider).value?.canAdminister == true)
                      lookup('assigned_to', 'Assigned representative', l.users),
                    text('progress', 'Progress', lines: 3),
                    text('notes', 'Notes', lines: 4),
                  ],
                  if (m == Module.rooms) ...[
                    text('name', 'Room name', required: true),
                    text('code', 'Room code', required: widget.record != null),
                    text('location', 'Location', required: true),
                    text('capacity', 'Capacity', required: true, number: true),
                    text('amenities_text', 'Amenities (comma separated)'),
                    toggle('is_active', 'Active'),
                  ],
                  if (m == Module.events) ...[
                    choices('category', 'Category', eventCategories),
                    toggle('is_all_day', 'All-day event'),
                    if (ref.read(authProvider).value?.canAdminister == true)
                      toggle('is_company_wide', 'Company-wide event'),
                  ],
                  if (m == Module.notes) ...[
                    text('agenda', 'Agenda', lines: 3),
                    text('discussion', 'Discussion', lines: 4),
                    text('decisions', 'Decisions', lines: 3),
                    text('action_items', 'Action items', lines: 3),
                    text(
                      'attachments_text',
                      'Document links (one per line)',
                      lines: 3,
                    ),
                    timeTile('Follow-up (optional)', 'due', due),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Saving…' : 'Save'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
