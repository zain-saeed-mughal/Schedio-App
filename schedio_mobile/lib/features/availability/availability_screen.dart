import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});
  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  DateTime? start;
  int duration = 60;
  int? room;
  final users = <int>{};
  bool busy = false;
  String? error, note;
  bool? conflict;
  List<({String name, String status})> people = [];
  List<Slot> suggestions = [];

  void reset() {
    error = null;
    note = null;
    conflict = null;
    people = [];
  }

  Future<void> pickStart(String zone) async {
    final today = tz.TZDateTime.now(locationFor(zone));
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(today),
    );
    if (time != null) {
      setState(() {
        start = tz.TZDateTime(
          locationFor(zone),
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ).toUtc();
        reset();
      });
    }
  }

  Future<void> check() async {
    setState(() {
      busy = true;
      reset();
    });
    try {
      final data = resultOf(
        await ref
            .read(apiProvider)
            .request(
              'availability/check',
              method: 'POST',
              data: {
                'start_time': isoWithOffset(start!),
                'end_time': isoWithOffset(start!.add(Duration(minutes: duration))),
                'room_id': room,
                'participant_ids': users.toList(),
              },
            ),
      );
      final names = {
        for (final u in ref.read(lookupsProvider).value?.users ?? const <Member>[]) u.id: u.name,
      };
      if (mounted) {
        setState(() {
          conflict = data['has_conflicts'] == true;
          people = [
            for (final p in (data['participants'] as List? ?? const []).whereType<Map>())
              (
                name: '${p['name'] ?? names[p['user_id']] ?? 'Participant ${p['user_id'] ?? ''}'}'.trim(),
                status: '${p['status'] ?? 'unknown'}',
              ),
          ];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> suggest(String zone) async {
    setState(() {
      busy = true;
      suggestions = [];
      note = null;
    });
    try {
      final response = await ref
          .read(apiProvider)
          .request(
            'availability/suggestions',
            query: {
              'date': DateFormat('yyyy-MM-dd').format(localIn(start!, zone)),
              'duration_minutes': duration,
              'room_id': room,
              'participant_ids[]': users.toList(),
            },
          );
      if (mounted) {
        setState(() {
          suggestions = slotsOf(response)
              .map((s) => Slot.fromJson(s as Json))
              .toList();
          if (suggestions.isEmpty) note = 'No alternative slots on this day.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
    return GlassPage(
      title: 'Check Availability',
      subtitle: zone,
      body: AsyncBody(
        value: ref.watch(lookupsProvider),
        retry: () => ref.invalidate(lookupsProvider),
        builder: (l) => ListView(
          padding: pageInsets(context),
          children: [
            const ScreenHeader(
              title: 'Find room for your next conversation',
              subtitle: 'Check people and rooms before you book.',
            ),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PickerTile(
                    label: 'Start time',
                    required: true,
                    value: start == null
                        ? 'Choose a time'
                        : '${shortDay(start, zone)}  ·  ${timeLabel(start, zone)}',
                    meta: zone,
                    placeholder: start == null,
                    onTap: () => pickStart(zone),
                  ),
                  const FieldLabel('Duration'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in [15, 30, 45, 60, 90, 120])
                          FilterPill(
                            label: n < 60 ? '$n min' : '${n ~/ 60}${n % 60 == 0 ? '' : '.5'} h',
                            selected: duration == n,
                            onTap: () => setState(() {
                              duration = n;
                              reset();
                            }),
                          ),
                      ],
                    ),
                  ),
                  AppDropdown<int>(
                    label: 'Room (optional)',
                    value: room,
                    padding: EdgeInsets.zero,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('No room')),
                      ...l.rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                    ],
                    onChanged: (n) => setState(() {
                      room = n;
                      reset();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Participants', style: AppText.cardTitle)),
                      if (users.isNotEmpty)
                        StatusPill(text: '${users.length} selected', tint: Tint.warning),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (l.users.isEmpty)
                    Text('No teammates to check yet.', style: AppText.helper),
                  ...l.users.map(
                    (u) => CheckRow(
                      title: u.name,
                      leading: AppAvatar(name: u.name, size: 30, radius: 10),
                      value: users.contains(u.id),
                      onChanged: (v) => setState(() {
                        v ? users.add(u.id) : users.remove(u.id);
                        reset();
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: busy ? 'Checking...' : 'Check availability',
              icon: Icons.fact_check_outlined,
              busy: busy,
              expand: true,
              onPressed: start == null ? null : check,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Suggest alternative times',
              icon: Icons.auto_awesome_outlined,
              variant: ButtonVariant.glass,
              expand: true,
              onPressed: busy || start == null ? null : () => suggest(zone),
            ),
            if (conflict != null) ...[
              const SizedBox(height: 18),
              InlineBanner(
                kind: conflict! ? BannerKind.error : BannerKind.success,
                title: conflict! ? 'There is a scheduling conflict' : 'No meeting conflict found',
                message: 'Availability is checked again when you save.',
                footer: people.isEmpty
                    ? null
                    : Column(
                        children: [
                          for (final p in people)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  AppAvatar(name: p.name, size: 26, radius: 8),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(p.name, style: AppText.helper.copyWith(color: AppColors.slate200)),
                                  ),
                                  StatusPill(
                                    text: titleCase(p.status),
                                    tint: p.status == 'available' ? Tint.success : Tint.danger,
                                    dot: true,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 18),
              InlineBanner(message: error!),
            ],
            if (note != null) ...[
              const SizedBox(height: 18),
              InlineBanner(kind: BannerKind.info, message: note!),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionHeader(title: 'Suggested times', dot: true),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions)
                    SlotPill(
                      label: timeLabel(s.start, zone),
                      selected: false,
                      onTap: () => setState(() {
                        start = s.start.toUtc();
                        reset();
                        suggestions = [];
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
