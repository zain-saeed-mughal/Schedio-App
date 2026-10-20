import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'editor.dart';

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
    MaterialPageRoute<void>(builder: (_) => RecordScreen(initial: record)),
  );
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
  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final account = ref.watch(authProvider).value;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(m.label),
        actions: [
          if (m == Module.notifications)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                try {
                  await ref
                      .read(apiProvider)
                      .request('notifications/mark-all-read', method: 'POST');
                  ref.read(refreshProvider.notifier).refresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () =>
                  openEditor(context, m, meetingId: widget.meetingId),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      body: Column(
        children: [
          if (![
            Module.notes,
            Module.notifications,
            Module.administration,
          ].contains(m))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() {
                  search = v.trim();
                  page = 1;
                }),
              ),
            ),
          if (statuses.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ...['', ...statuses].map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.isEmpty ? 'All' : label(s)),
                        selected: status == s,
                        onSelected: (_) => setState(() {
                          status = s;
                          page = 1;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AsyncBody(
              value: ref.watch(recordsProvider(query)),
              retry: () => ref.invalidate(recordsProvider(query)),
              builder: (result) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(recordsProvider(query));
                  await ref.read(recordsProvider(query).future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (result.records.isEmpty)
                      EmptyState(
                        title: 'Nothing here yet',
                        message: search.isNotEmpty || status.isNotEmpty
                            ? 'Try another search or filter.'
                            : 'Your ${m.label.toLowerCase()} will appear here.',
                      ),
                    ...result.records.map(
                      (r) => RecordTile(
                        record: r,
                        timezone: account?.timezone ?? 'UTC',
                        onTap: () => openRecord(context, r),
                      ),
                    ),
                    if (result.lastPage > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: page > 1
                                ? () => setState(() => page--)
                                : null,
                            child: const Text('Previous'),
                          ),
                          Text('$page / ${result.lastPage}'),
                          TextButton(
                            onPressed: page < result.lastPage
                                ? () => setState(() => page++)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  Future<void> action(
    String path, {
    String method = 'PATCH',
    Json? data,
    bool close = false,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).request(path, method: method, data: data);
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your workspace')),
        );
        if (close) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget info(String title, String? value) => value == null || value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(value),
            ],
          ),
        );
  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final hasDetail = ![
      Module.administration,
      Module.notifications,
    ].contains(initial.module);
    final provider = detailProvider((module: initial.module, id: initial.id));
    return Scaffold(
      appBar: AppBar(title: Text(initial.module.label)),
      body: AsyncBody<Record>(
        value: hasDetail ? ref.watch(provider) : AsyncData(initial),
        retry: () => ref.invalidate(provider),
        builder: (r) {
          final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
          final path = '${r.module.path}/${r.id}';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(r.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              if (r.status.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text(label(r.status))),
                ),
              info('Description', r.description),
              info('Starts', dateLabel(r.start, zone)),
              info('Ends', dateLabel(r.end, zone)),
              info('Due / follow-up', dateLabel(r.due, zone)),
              info('Organizer / assignee', r.owner),
              info('Location', r.location),
              info('Contact', r.contactName),
              info('Email', r.contactEmail ?? r.email),
              info('Phone', r.contactPhone),
              info('Contact role', r.contactRole),
              info('Campaign', r.campaign),
              info('Progress', r.progress),
              info('Deal value', r.dealValue),
              info('Notes', r.notes),
              info('Room code', r.code),
              info('Capacity', r.capacity?.toString()),
              info('Amenities', r.amenities.join(', ')),
              info('Attachments', r.attachments.join('\n')),
              info('Agenda', r.agenda),
              info('Discussion', r.discussion),
              info('Decisions', r.decisions),
              info('Action items', r.actionItems),
              info('Role', r.role),
              if (r.meetingLink != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open meeting link'),
                  onPressed: () async {
                    final uri = Uri.tryParse(r.meetingLink!);
                    if (uri != null && ['https', 'http'].contains(uri.scheme)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              if (r.participants.isNotEmpty) ...[
                const Text('Participants'),
                ...r.participants.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(p.name.substring(0, 1))),
                    title: Text(p.name),
                    trailing: Text(label(p.status ?? 'pending')),
                  ),
                ),
              ],
              if (r.module == Module.meetings) ...[
                if (r.canRsvp)
                  Wrap(
                    spacing: 8,
                    children: ['accepted', 'declined', 'tentative']
                        .map(
                          (s) => OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => action(
                                    '$path/rsvp',
                                    method: 'POST',
                                    data: {'status': s},
                                  ),
                            child: Text(label(s)),
                          ),
                        )
                        .toList(),
                  ),
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('Meeting notes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RecordsScreen(module: Module.notes, meetingId: r.id),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      openEditor(context, Module.tasks, meetingId: r.id),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Create action item'),
                ),
              ],
              if (r.module == Module.clients)
                OutlinedButton.icon(
                  onPressed: () => openEditor(
                    context,
                    Module.meetings,
                    clientId: int.parse(r.id),
                  ),
                  icon: const Icon(Icons.event),
                  label: const Text('Schedule client meeting'),
                ),
              if (r.module == Module.clients)
                ListTile(
                  title: const Text('Client meeting history'),
                  leading: const Icon(Icons.history),
                  trailing: const Icon(Icons.chevron_right),
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
              if (r.module == Module.tasks && r.meetingId != null)
                ListTile(
                  title: const Text('Related meeting'),
                  leading: const Icon(Icons.groups_outlined),
                  onTap: () => openRecord(
                    context,
                    Record.fromJson({
                      'id': r.meetingId,
                      'title': 'Meeting',
                    }, Module.meetings),
                  ),
                ),
              if ([Module.clients, Module.tasks].contains(r.module) &&
                  r.canManage)
                DropdownButtonFormField<String>(
                  initialValue: r.status,
                  decoration: const InputDecoration(labelText: 'Update status'),
                  items:
                      (r.module == Module.clients
                              ? clientStatuses
                              : taskStatuses)
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(label(s)),
                            ),
                          )
                          .toList(),
                  onChanged: busy
                      ? null
                      : (s) => action('$path/status', data: {'status': s}),
                ),
              if (r.module == Module.notifications) ...[
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action(
                          '$path/${r.isRead ? 'unread' : 'read'}',
                          close: true,
                        ),
                  child: Text(r.isRead ? 'Mark unread' : 'Mark read'),
                ),
                if (r.meetingId != null)
                  OutlinedButton(
                    onPressed: () => openRecord(
                      context,
                      Record.fromJson({
                        'id': r.meetingId,
                        'title': 'Meeting',
                      }, Module.meetings),
                    ),
                    child: const Text('View meeting'),
                  ),
              ],
              if (r.module == Module.administration &&
                  r.status == 'pending') ...[
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => action('$path/approve', close: true),
                  child: const Text('Approve request'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final reason = TextEditingController();
                          final value = await showDialog<String>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Reject request'),
                              content: TextField(
                                controller: reason,
                                decoration: const InputDecoration(
                                  labelText: 'Reason',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Back'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(c, reason.text),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          );
                          reason.dispose();
                          if (value != null) {
                            action(
                              '$path/reject',
                              data: {'rejection_reason': value},
                              close: true,
                            );
                          }
                        },
                  child: const Text('Reject request'),
                ),
              ],
              if (r.canManage &&
                  ![
                    Module.tasks,
                    Module.administration,
                    Module.notifications,
                  ].contains(r.module)) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => openEditor(context, r.module, record: r),
                  child: const Text('Edit'),
                ),
                if (r.module == Module.meetings && r.status != 'cancelled')
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirm(
                              context,
                              'Cancel this meeting?',
                            )) {
                              action('$path/cancel');
                            }
                          },
                    child: const Text('Cancel meeting'),
                  ),
              ],
              if ((r.canManage && r.module != Module.tasks) ||
                  r.module == Module.notifications)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm(context, 'Delete this item?')) {
                            action(path, method: 'DELETE', close: true);
                          }
                        },
                  child: const Text('Delete'),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}
