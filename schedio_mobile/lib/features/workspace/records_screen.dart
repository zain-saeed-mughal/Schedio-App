import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../settings/settings_screen.dart';
import 'editor.dart';
import 'registration_queue.dart';

void openEditor(
  BuildContext context,
  Module module, {
  Record? record,
  String? meetingId,
  int? clientId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Editor(
        module: module,
        record: record,
        meetingId: meetingId,
        clientId: clientId,
      ),
    ),
  );
}

void openRecord(BuildContext context, Record record) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => record.module == Module.administration
          ? RequestDetailScreen(record: record, workspace: 'Your company')
          : RecordScreen(initial: record),
    ),
  );
}

class ModuleCopy {
  final String title, subtitle, create, singular, empty;
  final IconData icon;
  const ModuleCopy(
    this.title,
    this.subtitle,
    this.create,
    this.singular,
    this.empty,
    this.icon,
  );

  static ModuleCopy of(Module m) => switch (m) {
    Module.meetings => const ModuleCopy(
      'My Meetings',
      'Every conversation on your calendar',
      'Schedule',
      'Meeting',
      'Meetings you host or join will appear here.',
      Icons.videocam_outlined,
    ),
    Module.tasks => const ModuleCopy(
      'My Tasks',
      'Action items and follow ups',
      'New Task',
      'Task',
      'Tasks assigned to you will appear here.',
      Icons.task_alt_rounded,
    ),
    Module.clients => const ModuleCopy(
      'Clients',
      'Your business development relationships',
      'Add Deal',
      'Client',
      'Clients and deals will appear here.',
      Icons.handshake_outlined,
    ),
    Module.rooms => const ModuleCopy(
      'Meeting Suites',
      'Focus pods, boardrooms and huddle spaces',
      'New Suite',
      'Meeting Suite',
      'Rooms your company can book will appear here.',
      Icons.meeting_room_outlined,
    ),
    Module.events => const ModuleCopy(
      'Events and Holidays',
      'Milestones, deadlines and time off',
      'New Event',
      'Event',
      'Company events and holidays will appear here.',
      Icons.celebration_outlined,
    ),
    Module.notes => const ModuleCopy(
      'Meeting Notes',
      'Agenda, decisions and action items',
      'New Note',
      'Meeting Note',
      'Notes captured for this meeting will appear here.',
      Icons.sticky_note_2_outlined,
    ),
    Module.notifications => const ModuleCopy(
      'Reminders and Alerts',
      'Your workspace activity feed',
      '',
      'Notification',
      'New activity in your workspace will appear here.',
      Icons.notifications_none_rounded,
    ),
    Module.administration => const ModuleCopy(
      'Registration Queue',
      'Review and manage requests',
      '',
      'Request',
      'There are no requests right now.',
      Icons.how_to_reg_outlined,
    ),
  };
}

class RecordsScreen extends ConsumerStatefulWidget {
  final Module module;
  final String? meetingId;
  final String? path;
  const RecordsScreen({
    super.key,
    required this.module,
    this.meetingId,
    this.path,
  });
  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  int page = 1;
  String search = '', status = '';
  bool preferences = false;

  Future<void> markAllRead() async {
    try {
      await ref
          .read(apiProvider)
          .request('notifications/mark-all-read', method: 'POST');
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) showToast(context, 'All caught up.');
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final copy = ModuleCopy.of(m);
    final account = ref.watch(authProvider).value;
    final inShell = ShellChrome.inShell(context);
    final query = (
      module: m,
      page: page,
      search: search,
      status: status,
      path:
          widget.path ??
          (widget.meetingId == null
              ? null
              : 'meetings/${widget.meetingId}/notes'),
    );
    final canCreate =
        ![Module.notifications, Module.administration].contains(m) &&
        widget.path == null &&
        (m != Module.rooms || account?.canManageRooms == true);
    final statuses = switch (m) {
      Module.clients => clientStatuses,
      Module.tasks => taskStatuses,
      Module.meetings => [
        'scheduled',
        'in_progress',
        'completed',
        'cancelled',
        'rescheduled',
      ],
      Module.administration => ['pending', 'approved', 'rejected'],
      Module.notifications => ['unread'],
      _ => <String>[],
    };
    final title = widget.path != null ? 'Client meeting history' : copy.title;

    final header = <Widget>[
      ScreenHeader(
        title: title,
        subtitle: copy.subtitle,
        trailing: canCreate
            ? AppButton(
                label: copy.create,
                icon: Icons.add_rounded,
                rotateIcon: true,
                size: ButtonSize.sm,
                onPressed: () =>
                    openEditor(context, m, meetingId: widget.meetingId),
              )
            : m == Module.notifications && !preferences
            ? AppButton(
                label: 'Mark all read',
                icon: Icons.done_all_rounded,
                variant: ButtonVariant.glass,
                size: ButtonSize.sm,
                onPressed: markAllRead,
              )
            : null,
      ),
      if (m == Module.notifications) ...[
        SegmentedTabs<bool>(
          selected: preferences,
          onChanged: (v) => setState(() => preferences = v),
          segments: const [
            Segment(false, 'Activity Feed', icon: Icons.bolt_rounded),
            Segment(true, 'Delivery Preferences', icon: Icons.tune_rounded),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (![
        Module.notes,
        Module.notifications,
        Module.administration,
      ].contains(m)) ...[
        AppSearchField(
          hint: 'Search ${copy.title.toLowerCase()}',
          initial: search,
          onChanged: (v) => setState(() {
            search = v;
            page = 1;
          }),
        ),
        const SizedBox(height: 12),
      ],
      if (statuses.isNotEmpty && !preferences) ...[
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final s in ['', ...statuses])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterPill(
                    label: s.isEmpty ? 'All' : titleCase(s),
                    selected: status == s,
                    dot: m == Module.clients && s.isNotEmpty
                        ? StageStyle.of(s).dot
                        : null,
                    onTap: () => setState(() {
                      status = s;
                      page = 1;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];

    final body = preferences
        ? ListView(
            padding: pageInsets(context),
            children: [...header, const NotificationPreferencesPanel()],
          )
        : AppRefresh(
            edgeOffset: topChrome(context),
            onRefresh: () async {
              ref.invalidate(recordsProvider(query));
              await ref.read(recordsProvider(query).future);
            },
            child: ref.watch(recordsProvider(query)).when(
              skipLoadingOnRefresh: true,
              loading: () => ListView(
                padding: pageInsets(context),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...header,
                  const SizedBox(
                    height: 420,
                    child: SkeletonList(padding: EdgeInsets.zero),
                  ),
                ],
              ),
              error: (e, _) => ListView(
                padding: pageInsets(context),
                children: [
                  ...header,
                  ErrorPanel(
                inline: true,
                    message: '$e',
                    retry: () => ref.invalidate(recordsProvider(query)),
                  ),
                ],
              ),
              data: (result) => ListView.builder(
                padding: pageInsets(context),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount:
                    header.length +
                    (result.records.isEmpty ? 1 : result.records.length) +
                    (result.lastPage > 1 ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i < header.length) return header[i];
                  final index = i - header.length;
                  if (result.records.isEmpty && index == 0) {
                    return EmptyState(
                      icon: copy.icon,
                      title: 'Nothing here yet',
                      message: search.isNotEmpty || status.isNotEmpty
                          ? 'Try another search or filter.'
                          : copy.empty,
                      actionLabel: canCreate ? copy.create : null,
                      onAction: canCreate
                          ? () => openEditor(context, m, meetingId: widget.meetingId)
                          : null,
                    );
                  }
                  if (index < result.records.length) {
                    final r = result.records[index];
                    return StaggeredEntrance(
                      index: index,
                      child: RecordTile(
                        record: r,
                        timezone: account?.timezone ?? 'UTC',
                        onTap: () => openRecord(context, r),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        AppButton(
                          label: 'Previous',
                          icon: Icons.chevron_left_rounded,
                          variant: ButtonVariant.glass,
                          size: ButtonSize.sm,
                          onPressed: page > 1 ? () => setState(() => page--) : null,
                        ),
                        Expanded(
                          child: Text(
                            '$page / ${result.lastPage}',
                            textAlign: TextAlign.center,
                            style: AppText.monoMuted,
                          ),
                        ),
                        AppButton(
                          label: 'Next',
                          trailingIcon: Icons.chevron_right_rounded,
                          variant: ButtonVariant.glass,
                          size: ButtonSize.sm,
                          onPressed: page < result.lastPage
                              ? () => setState(() => page++)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );

    if (inShell && widget.path == null) {
      return TabPage(title: title, child: body);
    }
    return GlassPage(title: title, subtitle: copy.subtitle, body: body);
  }
}

class RecordScreen extends ConsumerStatefulWidget {
  final Record initial;
  const RecordScreen({super.key, required this.initial});
  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  bool busy = false;
  String? error;
  String? rsvp;
  bool? read;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r.module == Module.notifications && !r.isRead) {
      read = true;
      ref
          .read(apiProvider)
          .request('${r.module.path}/${r.id}/read', method: 'PATCH')
          .then((_) => ref.read(refreshProvider.notifier).refresh())
          .catchError((Object _) {
            if (mounted) setState(() => read = false);
          });
    }
  }

  Future<bool> action(
    String path, {
    String method = 'PATCH',
    Json? data,
    bool close = false,
    String message = 'Saved to your workspace',
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).request(path, method: method, data: data);
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) {
        showToast(context, message);
        if (close) Navigator.pop(context);
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
        showToast(context, e.toString(), error: true);
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final hasDetail = ![
      Module.administration,
      Module.notifications,
    ].contains(initial.module);
    final provider = detailProvider((module: initial.module, id: initial.id));
    final copy = ModuleCopy.of(initial.module);
    return GlassPage(
      title: copy.singular,
      subtitle: copy.title,
      body: AsyncBody<Record>(
        value: hasDetail ? ref.watch(provider) : AsyncData(initial),
        retry: () => ref.invalidate(provider),
        builder: (r) {
          final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
          final me = ref.watch(authProvider).value?.id;
          final path = '${r.module.path}/${r.id}';
          final mine = r.participants.where((p) => p.id == me).firstOrNull;
          final currentRsvp = rsvp ?? mine?.status;
          final isRead = read ?? r.isRead;
          final sections = <Widget>[
            _HeroCard(record: r, timezone: zone),
            if (r.module == Module.meetings && r.meetingLink != null && r.status != 'cancelled')
              AppButton(
                label: 'Join Call',
                icon: Icons.videocam_rounded,
                variant: ButtonVariant.success,
                expand: true,
                onPressed: () => openLink(context, r.meetingLink),
              ),
            if (r.module == Module.meetings && r.canRsvp)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your RSVP', style: AppText.cardTitle),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final (s, tint, icon) in [
                          ('accepted', Tint.success, Icons.check_circle_outline_rounded),
                          ('tentative', Tint.warning, Icons.help_outline_rounded),
                          ('declined', Tint.danger, Icons.cancel_outlined),
                        ]) ...[
                          if (s != 'accepted') const SizedBox(width: 8),
                          Expanded(
                            child: _RsvpCard(
                              label: titleCase(s),
                              icon: icon,
                              tint: tint,
                              selected: currentRsvp == s,
                              onTap: busy
                                  ? null
                                  : () async {
                                      final before = rsvp;
                                      setState(() => rsvp = s);
                                      final ok = await action(
                                        '$path/rsvp',
                                        method: 'POST',
                                        data: {'status': s},
                                        message: 'RSVP updated',
                                      );
                                      if (!ok && mounted) setState(() => rsvp = before);
                                    },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            _DetailsCard(record: r, timezone: zone),
            if (r.participants.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Participants', style: AppText.cardTitle)),
                        StatusPill(text: '${r.participants.length}', tint: Tint.neutral),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final p in r.participants)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            AppAvatar(name: p.name, size: 36, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.id == me ? '${p.name} (you)' : p.name,
                                style: AppText.rowTitle.copyWith(fontSize: 13),
                              ),
                            ),
                            StatusPill.status(
                              p.id == me && rsvp != null ? rsvp! : p.status ?? 'pending',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (r.module == Module.meetings)
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.sticky_note_2_outlined,
                      tint: Tint.purple,
                      title: 'Meeting notes',
                      subtitle: 'Agenda, decisions and action items',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RecordsScreen(module: Module.notes, meetingId: r.id),
                        ),
                      ),
                    ),
                    DetailRow(
                      icon: Icons.add_task_rounded,
                      tint: Tint.success,
                      title: 'Create action item',
                      subtitle: 'Assign a follow up task from this meeting',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                      onTap: () => openEditor(context, Module.tasks, meetingId: r.id),
                    ),
                  ],
                ),
              ),
            if (r.module == Module.clients)
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.event_rounded,
                      title: 'Schedule client meeting',
                      subtitle: 'Book time with ${r.contactName ?? r.title}',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                      onTap: () => openEditor(context, Module.meetings, clientId: int.parse(r.id)),
                    ),
                    DetailRow(
                      icon: Icons.history_rounded,
                      tint: Tint.indigo,
                      title: 'Client meeting history',
                      subtitle: 'Every meeting with this client',
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RecordsScreen(
                            module: Module.meetings,
                            path: 'clients/${r.id}/meetings',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (r.module == Module.tasks && r.meetingId != null)
              DetailRow(
                icon: Icons.videocam_outlined,
                tint: Tint.indigo,
                title: 'Related meeting',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                onTap: () => openRecord(
                  context,
                  Record.fromJson({'id': r.meetingId, 'title': 'Meeting'}, Module.meetings),
                ),
              ),
            if ([Module.clients, Module.tasks].contains(r.module) && r.canManage)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      r.module == Module.clients ? 'Pipeline stage' : 'Update status',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in r.module == Module.clients ? clientStatuses : taskStatuses)
                          FilterPill(
                            label: titleCase(s),
                            selected: r.status == s,
                            dot: r.module == Module.clients ? StageStyle.of(s).dot : null,
                            onTap: busy || r.status == s
                                ? () {}
                                : () => action('$path/status', data: {'status': s}, message: 'Status updated'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (r.module == Module.notifications)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: isRead ? 'Mark unread' : 'Mark read',
                      variant: ButtonVariant.glass,
                      icon: isRead ? Icons.mark_email_unread_outlined : Icons.done_rounded,
                      onPressed: busy
                          ? null
                          : () async {
                              final ok = await action('$path/${isRead ? 'unread' : 'read'}');
                              if (ok && mounted) setState(() => read = !isRead);
                            },
                    ),
                  ),
                  if (r.meetingId != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'View meeting',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () => openRecord(
                          context,
                          Record.fromJson({'id': r.meetingId, 'title': 'Meeting'}, Module.meetings),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (r.canManage &&
                ![Module.tasks, Module.administration, Module.notifications].contains(r.module))
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                expand: true,
                onPressed: busy ? null : () => openEditor(context, r.module, record: r),
              ),
            if ((r.canManage && r.module != Module.tasks) || r.module == Module.notifications)
              Row(
                children: [
                  if (r.canManage && r.module == Module.meetings && r.status != 'cancelled') ...[
                    Expanded(
                      child: AppButton(
                        label: 'Cancel meeting',
                        variant: ButtonVariant.outline,
                        onPressed: busy
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  'Cancel this meeting?',
                                  message: 'Participants are notified that the meeting is cancelled.',
                                  confirmLabel: 'Cancel meeting',
                                  destructive: true,
                                )) {
                                  action('$path/cancel', message: 'Meeting cancelled');
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: AppButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      variant: ButtonVariant.danger,
                      onPressed: busy
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                'Delete this item?',
                                confirmLabel: 'Delete',
                                destructive: true,
                              )) {
                                action(path, method: 'DELETE', close: true, message: 'Deleted');
                              }
                            },
                    ),
                  ),
                ],
              ),
            if (error != null) InlineBanner(message: error!),
            if (busy) const LinearProgressIndicator(minHeight: 2),
          ];
          return ListView(
            padding: pageInsets(context),
            children: [
              for (var i = 0; i < sections.length; i++)
                StaggeredEntrance(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: sections[i],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Record record;
  final String timezone;
  const _HeroCard({required this.record, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final copy = ModuleCopy.of(r.module);
    final pills = <Widget>[
      if (r.module == Module.meetings && r.status.isNotEmpty)
        StatusPill(text: titleCase(r.status), tint: meetingStatusTint(r.status), dot: true, size: PillSize.md),
      if (r.module == Module.meetings && r.isClientMeeting)
        const StatusPill(text: 'Client meeting', tint: Tint.purple, size: PillSize.md),
      if (r.module == Module.meetings && r.isPrivate)
        const StatusPill(text: 'Private', tint: Tint.neutral, icon: Icons.lock_outline_rounded, size: PillSize.md),
      if (r.module == Module.tasks && r.status.isNotEmpty)
        StatusPill(text: titleCase(r.status), tint: taskStatusTint(r.status), dot: true, size: PillSize.md),
      if (r.module == Module.tasks && r.priority != null)
        StatusPill(text: '${titleCase(r.priority!)} priority', tint: priorityTint(r.priority!), size: PillSize.md),
      if (r.module == Module.clients) StageBadge(stage: StageStyle.of(r.status)),
      if (r.module == Module.clients && (r.dealValue?.isNotEmpty ?? false)) ValueChip(value: money(r.dealValue)),
      if (r.module == Module.rooms)
        StatusPill(
          text: r.isActive ? 'Available' : 'Inactive',
          tint: r.isActive ? Tint.success : Tint.neutral,
          dot: true,
          size: PillSize.md,
        ),
      if (r.module == Module.events && r.category != null)
        StatusPill(text: titleCase(r.category!), tint: eventTint(r.category), size: PillSize.md),
      if (r.module == Module.events && r.isCompanyWide)
        const StatusPill(text: 'Company wide', tint: Tint.info, size: PillSize.md),
      if (r.module == Module.notifications)
        StatusPill(
          text: r.isRead ? 'Read' : 'New',
          tint: r.isRead ? Tint.neutral : Tint.warning,
          dot: true,
          size: PillSize.md,
        ),
    ];
    return GlassCard(
      tone: GlassTone.panel,
      accentEdge: true,
      sweep: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              r.module == Module.clients
                  ? AppAvatar(name: r.title, size: 48, kind: AvatarKind.monogram)
                  : IconTile(
                      icon: copy.icon,
                      size: 48,
                      iconSize: 22,
                      radius: AppRadii.innerAll,
                      tint: r.module == Module.meetings && r.isClientMeeting
                          ? Tint.purple
                          : Tint.warning,
                    ),
              const Spacer(),
              if (r.start != null && r.module != Module.notes)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r.isAllDay ? 'All day' : timeLabel(r.start, timezone),
                      style: AppText.monoData.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(shortDay(r.start, timezone), style: AppText.monoTiny),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(r.title, style: AppText.screenTitle.copyWith(fontSize: 24)),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: pills),
          ],
          if (r.module == Module.clients) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('PIPELINE FLOW', style: AppText.tiny),
                const SizedBox(width: 8),
                Text(
                  StageStyle.of(r.status).label,
                  style: AppText.tiny.copyWith(color: AppColors.amber400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentProgress(step: StageStyle.of(r.status).step),
          ],
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            SelectableText(r.description, style: AppText.body),
          ],
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Record record;
  final String timezone;
  const _DetailsCard({required this.record, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rows = <Widget>[
      if (r.start != null && r.end != null && r.module != Module.notes)
        DetailRow(
          icon: Icons.schedule_rounded,
          title: r.isAllDay
              ? shortDay(r.start, timezone)
              : '${timeLabel(r.start, timezone)} to ${timeLabel(r.end, timezone)}',
          subtitle: '${shortDay(r.start, timezone)} · ${r.timezone ?? timezone}',
        ),
      if (r.due != null)
        DetailRow(
          icon: Icons.flag_outlined,
          tint: Tint.danger,
          title: dateLabel(r.due, timezone),
          subtitle: r.module == Module.notes ? 'Follow up' : 'Due',
        ),
      if (r.owner != null)
        DetailRow(
          icon: Icons.person_outline_rounded,
          tint: Tint.indigo,
          title: r.owner!,
          subtitle: r.module == Module.meetings ? 'Organizer' : 'Owner',
        ),
      if (r.clientName != null || r.clientCompany != null)
        DetailRow(
          icon: Icons.handshake_outlined,
          tint: Tint.purple,
          title: r.clientName ?? r.clientCompany!,
          subtitle: [r.clientCompany, r.clientEmail]
              .whereType<String>()
              .where((v) => v != r.clientName)
              .join(' · '),
          selectable: true,
        ),
      if (r.type != null && r.module == Module.meetings)
        DetailRow(icon: Icons.devices_rounded, tint: Tint.info, title: titleCase(r.type!), subtitle: 'Format'),
      if (r.location != null && r.location!.isNotEmpty)
        DetailRow(icon: Icons.place_outlined, tint: Tint.success, title: r.location!, subtitle: 'Location'),
      if (r.meetingLink != null)
        DetailRow(
          icon: Icons.link_rounded,
          tint: Tint.indigo,
          title: r.meetingLink!,
          subtitle: 'Video link',
          onTap: () => openLink(context, r.meetingLink),
        ),
      if (r.contactName != null)
        DetailRow(
          icon: Icons.person_outline_rounded,
          tint: Tint.indigo,
          title: r.contactName!,
          subtitle: r.contactRole ?? 'Contact',
        ),
      if ((r.contactEmail ?? (r.module == Module.notifications ? null : r.email)) != null)
        DetailRow(
          icon: Icons.mail_outline_rounded,
          title: (r.contactEmail ?? r.email)!,
          subtitle: 'Email',
          selectable: true,
        ),
      if (r.contactPhone != null)
        DetailRow(icon: Icons.phone_outlined, title: r.contactPhone!, subtitle: 'Phone', selectable: true),
      if (r.campaign != null)
        DetailRow(icon: Icons.track_changes_rounded, tint: Tint.indigo, title: r.campaign!, subtitle: 'Campaign'),
      if (r.code != null)
        DetailRow(icon: Icons.tag_rounded, tint: Tint.neutral, title: r.code!, subtitle: 'Room code'),
      if (r.capacity != null)
        DetailRow(icon: Icons.people_alt_outlined, tint: Tint.info, title: '${r.capacity} people', subtitle: 'Capacity'),
      if (r.role != null && r.module != Module.administration)
        DetailRow(icon: Icons.badge_outlined, tint: Tint.neutral, title: titleCase(r.role!), subtitle: 'Role'),
    ];
    final blocks = <Widget>[
      if (r.amenities.isNotEmpty) ...[
        Text('AMENITIES', style: AppText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final a in r.amenities) StatusPill(text: a, size: PillSize.md)],
        ),
        const SizedBox(height: 16),
      ],
      for (final (title, value, icon) in [
        ('Progress', r.progress, Icons.trending_up_rounded),
        ('Notes', r.notes, Icons.notes_rounded),
        ('Agenda', r.agenda, Icons.list_alt_rounded),
        ('Discussion', r.discussion, Icons.forum_outlined),
        ('Decisions', r.decisions, Icons.gavel_rounded),
        ('Action items', r.actionItems, Icons.checklist_rounded),
        ('Documents', r.attachments.join('\n'), Icons.attach_file_rounded),
      ])
        if (value != null && value.isNotEmpty)
          LabeledBlock(label: title, value: value, icon: icon),
    ];
    if (rows.isEmpty && blocks.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Details', style: AppText.cardTitle),
          const SizedBox(height: 14),
          ...rows,
          if (rows.isNotEmpty && blocks.isNotEmpty) const SizedBox(height: 8),
          ...blocks,
        ],
      ),
    );
  }
}

class _RsvpCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Tint tint;
  final bool selected;
  final VoidCallback? onTap;
  const _RsvpCard({
    required this.label,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  Color get deep => switch (tint) {
    Tint.success => AppColors.emerald950,
    Tint.danger => AppColors.rose950,
    _ => AppColors.amber950,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'RSVP $label',
    child: GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              haptic(HapticKind.selection);
              onTap!();
            },
      child: AnimatedContainer(
        duration: AppMotion.pill,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? deep.withValues(alpha: 0.4) : AppColors.slate950.withValues(alpha: 0.4),
          borderRadius: AppRadii.controlAll,
          border: Border.all(
            color: selected ? tint.base : AppColors.slate800,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: tint.base.withValues(alpha: 0.25), blurRadius: 12)]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? tint.text : AppColors.slate400),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.helper.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? tint.text : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
