import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/api.dart';
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
const officialTaskStatuses = ['pending', 'in_progress', 'completed'];

List<String> taskStatusesFor(String current, {List<String> server = const []}) =>
    server.isNotEmpty
    ? server
    : taskStatuses.contains(current)
    ? taskStatuses
    : officialTaskStatuses;
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
  final DateTime? initialStart;
  const Editor({
    super.key,
    required this.module,
    this.record,
    this.meetingId,
    this.clientId,
    this.initialStart,
  });
  @override
  ConsumerState<Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<Editor> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final fields = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  final participantIds = <int>{};
  DateTime? start, end, due;
  bool busy = false;
  String? error, baseline;
  List<Slot> suggestions = [];
  String get zone => ref.read(authProvider).value?.timezone ?? 'UTC';

  String snapshot() => [
    for (final e in fields.entries) '${e.key}=${e.value.text}',
    for (final e in values.entries) '${e.key}=${e.value}',
    (participantIds.toList()..sort()).join(','),
    start,
    end,
    due,
  ].join('|');

  bool get dirty => baseline != null && snapshot() != baseline;

  Future<void> leave() async {
    if (busy) return;
    if (!dirty ||
        await confirm(
          context,
          'Discard changes?',
          message: 'Your edits have not been saved.',
          confirmLabel: 'Discard',
          destructive: true,
        )) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    start = r?.start ?? widget.initialStart;
    end = r?.end ?? widget.initialStart?.add(const Duration(minutes: 30));
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
    scroll.dispose();
    super.dispose();
  }

  Widget text(
    String key,
    String title, {
    bool required = false,
    int lines = 1,
    bool number = false,
    IconData? icon,
    Color? iconColor,
    Color? labelColor,
    String? hint,
    TextInputType? keyboard,
  }) => AppField(
    label: title,
    controller: fields.putIfAbsent(key, TextEditingController.new),
    required: required,
    maxLines: lines,
    hint: hint,
    prefixIcon: icon,
    prefixColor: iconColor,
    labelColor: labelColor,
    keyboardType: keyboard ?? (number ? TextInputType.number : TextInputType.text),
    validator: (v) => required && (v == null || v.trim().isEmpty)
        ? '$title is required'
        : null,
  );

  Widget choices(String key, String title, List<String> options) =>
      AppDropdown<String>(
        label: title,
        value: options.contains(values[key])
            ? values[key] as String
            : options.first,
        items: options
            .map((v) => DropdownMenuItem(value: v, child: Text(titleCase(v))))
            .toList(),
        onChanged: (v) => values[key] = v,
      );

  Widget lookup(String key, String title, List<Member> options, {Color? labelColor}) =>
      AppDropdown<int>(
        label: title,
        labelColor: labelColor,
        value: options.any((m) => m.id == values[key])
            ? values[key] as int?
            : null,
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('None')),
          ...options.map(
            (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
          ),
        ],
        onChanged: (v) => values[key] = v,
      );

  Widget toggle(String key, String title, {String? subtitle, IconData? icon}) =>
      SwitchRow(
        title: title,
        subtitle: subtitle,
        icon: icon,
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
        final length = start != null && end != null ? end!.difference(start!) : const Duration(hours: 1);
        start = result.toUtc();
        end = start!.add(length.isNegative ? const Duration(hours: 1) : length);
      } else if (kind == 'end') {
        end = result.toUtc();
      } else {
        due = result.toUtc();
      }
    });
  }

  Widget timeTile(String title, String kind, DateTime? value, {bool required = false}) => PickerTile(
    label: title,
    required: required,
    icon: kind == 'due' ? Icons.flag_outlined : Icons.schedule_rounded,
    value: value == null ? 'Choose date and time' : '${shortDay(value, zone)}  ·  ${timeLabel(value, zone)}',
    meta: zone,
    placeholder: value == null,
    onTap: () => pick(kind),
  );

  Future<void> loadSuggestions() async {
    if (start == null || end == null) return;
    try {
      final response = await ref
          .read(apiProvider)
          .request(
            'availability/suggestions',
            query: {
              'date': DateFormat('yyyy-MM-dd').format(localIn(start!, zone)),
              'duration_minutes': end!.difference(start!).inMinutes,
              'room_id': values['room_id'],
              'participant_ids[]': participantIds.toList(),
            },
          );
      if (!mounted) return;
      setState(
        () => suggestions = slotsOf(response)
            .map((s) => Slot.fromJson(s as Json))
            .take(6)
            .toList(),
      );
    } catch (_) {}
  }

  void showError(String message) {
    setState(() => error = message);
    if (scroll.hasClients) {
      scroll.animateTo(0, duration: AppMotion.page, curve: AppMotion.signature);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final m = widget.module;
    if (m == Module.meetings &&
        values['is_client_meeting'] == true &&
        values['save_as_client'] == true &&
        values['client_id'] != null) {
      showError('Choose either an existing client or save a new client.');
      return;
    }
    if ([Module.meetings, Module.events].contains(m) &&
        (start == null || end == null || !end!.isAfter(start!))) {
      showError('Choose an end time after the start time.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      suggestions = [];
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
      payload['start_time'] = apiTime(start!, zone);
      payload['end_time'] = apiTime(end!, zone);
    }
    if (m == Module.tasks) {
      payload['due_date'] = due == null ? null : apiTime(due!, zone);
      payload['meeting_id'] = widget.meetingId ?? widget.record?.meetingId;
    }
    if (m == Module.notes) {
      payload['follow_up_date'] = due == null ? null : apiTime(due!, zone);
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
        showToast(
          context,
          widget.record == null ? '${ModuleTitle.of(m)} created.' : 'Changes saved.',
        );
        Navigator.pop(context, true);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        showError(e.message);
        if (m == Module.meetings && (e.status == 409 || e.status == 422)) {
          loadSuggestions();
        }
      }
    } catch (e) {
      if (mounted) showError(friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget section(String title, List<Widget> children, {IconData? icon, Tint? tint, Color? border, Color? fill}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
          borderColor: border,
          fill: fill,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    IconTile(icon: icon, tint: tint ?? Tint.warning, size: 32, iconSize: 16),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: Text(title, style: AppText.cardTitle.copyWith(fontSize: 15))),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  List<Widget> meetingForm(Lookups l) {
    final length = start != null && end != null ? end!.difference(start!).inMinutes : null;
    return [
      section('Basics', [
        text('title', 'Title', required: true, hint: 'Quarterly review with the team'),
      ], icon: Icons.edit_note_rounded),
      section(
        'Client info',
        [
          toggle(
            'is_client_meeting',
            'External guest',
            subtitle: 'Invite someone from outside your workspace',
            icon: Icons.person_add_alt_outlined,
          ),
          lookup('client_id', 'Client', l.clients, labelColor: AppColors.purple300),
          if (values['is_client_meeting'] == true) ...[
            text('client_name', 'Guest name', labelColor: AppColors.purple300),
            text(
              'client_email',
              'Guest email',
              labelColor: AppColors.purple300,
              keyboard: TextInputType.emailAddress,
            ),
            text(
              'client_company',
              'Guest company',
              required: values['save_as_client'] == true,
              labelColor: AppColors.purple300,
            ),
            if (widget.record == null) ...[
              toggle('save_as_client', 'Save guest as a new client'),
              if (values['save_as_client'] == true) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Leave Client as None to create a new client with this meeting.',
                    style: AppText.helper,
                  ),
                ),
                text('campaign', 'Campaign', labelColor: AppColors.purple300),
              ],
            ],
          ],
        ],
        icon: Icons.handshake_outlined,
        tint: Tint.purple,
      ),
      section('When', [
        timeTile('Starts', 'start', start, required: true),
        timeTile('Ends', 'end', end, required: true),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (mins, text) in [(30, '30 min'), (45, '45 min'), (60, '1 hour')])
                FilterPill(
                  label: text,
                  selected: length == mins,
                  onTap: () => setState(() {
                    start ??= DateTime.now().toUtc().add(const Duration(hours: 1));
                    end = start!.add(Duration(minutes: mins));
                  }),
                ),
            ],
          ),
        ),
      ], icon: Icons.schedule_rounded),
      section('Where', [
        text(
          'meeting_link',
          'Video call link',
          icon: Icons.videocam_outlined,
          iconColor: AppColors.indigo300,
          hint: 'Google Meet, Zoom or Teams link',
          keyboard: TextInputType.url,
        ),
        const FieldLabel('Meeting type'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SegmentedTabs<String>(
            compact: true,
            selected: values['type'] as String,
            onChanged: (v) => setState(() => values['type'] = v),
            segments: const [
              Segment('virtual', 'Virtual'),
              Segment('in_person', 'In person'),
              Segment('hybrid', 'Hybrid'),
            ],
          ),
        ),
        text('location', 'Location', icon: Icons.place_outlined),
        lookup('room_id', 'Room', l.rooms),
        lookup('department_id', 'Department', l.departments),
      ], icon: Icons.place_outlined, tint: Tint.success),
      section(
        'Reminder',
        [
          AppDropdown<int>(
            label: 'Remind me',
            labelColor: AppColors.amber300,
            value: values['reminder_minutes'] as int,
            items: [5, 10, 15, 30, 60, 1440, 0]
                .map(
                  (n) => DropdownMenuItem(
                    value: n,
                    child: Text(
                      n == 0
                          ? 'No reminder'
                          : n == 1440
                          ? '1 day before'
                          : n == 15
                          ? '15 minutes before (Recommended)'
                          : '$n minutes before',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => values['reminder_minutes'] = v,
          ),
        ],
        icon: Icons.notifications_active_outlined,
        fill: AppColors.amber950.withValues(alpha: 0.3),
        border: AppColors.amber(0.3),
      ),
      section('Participants', [
        if (l.users.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('No teammates to invite yet.', style: AppText.helper),
          ),
        ...l.users.map(
          (u) => CheckRow(
            title: u.name,
            leading: AppAvatar(name: u.name, size: 30, radius: 10),
            value: participantIds.contains(u.id),
            onChanged: (v) => setState(() {
              v ? participantIds.add(u.id) : participantIds.remove(u.id);
            }),
          ),
        ),
        const SizedBox(height: 8),
      ], icon: Icons.groups_2_outlined, tint: Tint.indigo),
      section('Notes and agenda', [
        text('description', 'Notes / Agenda', lines: 4, hint: 'What should everyone prepare?'),
        if (widget.record == null) ...[
          choices('recurrence_frequency', 'Recurrence preference', [
            'none',
            'daily',
            'weekly',
            'biweekly',
            'monthly',
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'This records a recurrence preference. Additional meeting instances are not scheduled automatically.',
              style: AppText.helper,
            ),
          ),
        ],
        toggle('is_private', 'Private meeting', icon: Icons.lock_outline_rounded),
      ], icon: Icons.notes_rounded, tint: Tint.neutral),
    ];
  }

  List<Widget> formFor(Lookups l) {
    final m = widget.module;
    final admin = ref.read(authProvider).value?.canAdminister == true;
    return switch (m) {
      Module.meetings => meetingForm(l),
      Module.tasks => [
        section('Task', [
          text('title', 'Title', required: true),
          text('description', 'Description', lines: 3),
          choices('priority', 'Priority', ['low', 'medium', 'high', 'urgent']),
          lookup('assigned_to', 'Assigned to', l.users),
          lookup('department_id', 'Department', l.departments),
          timeTile('Due date (optional)', 'due', due),
        ], icon: Icons.task_alt_rounded, tint: Tint.success),
      ],
      Module.clients => [
        section('Company', [
          text('company_name', 'Company name', required: true, icon: Icons.apartment_rounded),
          text('campaign', 'Campaign', icon: Icons.track_changes_rounded),
          choices('status', 'Pipeline stage', clientStatuses),
          text('deal_value', 'Deal value', number: true, icon: Icons.attach_money_rounded),
          if (admin) lookup('assigned_to', 'Assigned representative', l.users),
        ], icon: Icons.apartment_rounded),
        section('Contact', [
          text('contact_name', 'Contact name', required: true, icon: Icons.person_outline_rounded),
          text('contact_email', 'Contact email', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
          text('contact_phone', 'Contact phone', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
          text('contact_role', 'Contact role', icon: Icons.badge_outlined),
        ], icon: Icons.person_outline_rounded, tint: Tint.indigo),
        section('Notes', [
          text('progress', 'Progress', lines: 3),
          text('notes', 'Notes', lines: 4),
        ], icon: Icons.notes_rounded, tint: Tint.neutral),
      ],
      Module.rooms => [
        section('Meeting suite', [
          text('name', 'Room name', required: true),
          text('code', 'Room code', required: widget.record != null),
          text('location', 'Location', required: true, icon: Icons.place_outlined),
          text('capacity', 'Capacity', required: true, number: true, icon: Icons.people_alt_outlined),
          text('amenities_text', 'Amenities (comma separated)', hint: 'Display, whiteboard, conference phone'),
          toggle('is_active', 'Active', subtitle: 'Available for booking'),
        ], icon: Icons.meeting_room_outlined, tint: Tint.indigo),
      ],
      Module.events => [
        section('Event', [
          text('title', 'Title', required: true),
          text('description', 'Description', lines: 3),
          choices('category', 'Category', eventCategories),
        ], icon: Icons.celebration_outlined, tint: Tint.info),
        section('When and where', [
          timeTile('Starts', 'start', start, required: true),
          timeTile('Ends', 'end', end, required: true),
          toggle('is_all_day', 'All day event'),
          if (admin) toggle('is_company_wide', 'Company wide event'),
          lookup('department_id', 'Department', l.departments),
          text('location', 'Location', icon: Icons.place_outlined),
        ], icon: Icons.schedule_rounded),
      ],
      Module.notes => [
        section('Meeting note', [
          text('agenda', 'Agenda', lines: 3),
          text('discussion', 'Discussion', lines: 4),
          text('decisions', 'Decisions', lines: 3),
          text('action_items', 'Action items', lines: 3),
          text('attachments_text', 'Document links (one per line)', lines: 3),
          timeTile('Follow up (optional)', 'due', due),
        ], icon: Icons.sticky_note_2_outlined, tint: Tint.purple),
      ],
      _ => <Widget>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final meeting = m == Module.meetings;
    final title = '${widget.record == null ? 'New' : 'Edit'} ${ModuleTitle.of(m).toLowerCase()}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: GlassPage(
      title: title,
      subtitle: [Module.meetings, Module.events].contains(m) ? zone : null,
      bottomBar: Row(
        children: [
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'Cancel',
              variant: ButtonVariant.secondary,
              onPressed: busy ? null : leave,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: AppButton(
              label: busy
                  ? (meeting ? 'Scheduling...' : 'Saving...')
                  : (meeting ? 'Save & Set Reminder' : 'Save'),
              busy: busy,
              haptic: HapticKind.medium,
              onPressed: save,
            ),
          ),
        ],
      ),
      body: AsyncBody(
        value: ref.watch(lookupsProvider),
        retry: () => ref.invalidate(lookupsProvider),
        builder: (l) {
          if (baseline == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) baseline ??= snapshot();
            });
          }
          return Form(
          key: form,
          child: ListView(
            controller: scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: pageInsets(context, bottom: 110),
            children: [
              ScreenHeader(
                title: title.substring(0, 1).toUpperCase() + title.substring(1),
                subtitle: widget.record == null
                    ? 'Changes sync to your Schedio workspace.'
                    : widget.record!.title,
              ),
              if (error != null) ...[
                InlineBanner(
                  message: error!,
                  footer: suggestions.isEmpty
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRY ONE OF THESE TIMES',
                              style: AppText.tiny.copyWith(color: AppColors.rose300),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final s in suggestions)
                                  SlotPill(
                                    label: '${shortDay(s.start, zone)} ${timeLabel(s.start, zone)}',
                                    selected: false,
                                    onTap: () => setState(() {
                                      final length = end!.difference(start!);
                                      start = s.start.toUtc();
                                      end = start!.add(length);
                                      error = null;
                                      suggestions = [];
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
              ],
              ...formFor(l),
            ],
          ),
          );
        },
      ),
      ),
    );
  }
}

class ModuleTitle {
  static String of(Module m) => switch (m) {
    Module.meetings => 'Meeting',
    Module.tasks => 'Task',
    Module.clients => 'Client',
    Module.rooms => 'Meeting suite',
    Module.events => 'Event',
    Module.notes => 'Meeting note',
    Module.notifications => 'Notification',
    Module.administration => 'Request',
  };
}
