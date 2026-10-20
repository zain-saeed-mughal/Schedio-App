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
  String? result;
  List<Slot> suggestions = [];
  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
    return Scaffold(
      appBar: AppBar(title: const Text('Check availability')),
      body: AsyncBody(
        value: ref.watch(lookupsProvider),
        retry: () => ref.invalidate(lookupsProvider),
        builder: (l) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Find room for your next conversation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ListTile(
              title: const Text('Start time'),
              subtitle: Text(
                start == null
                    ? 'Choose a time · $zone'
                    : dateLabel(start, zone),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final today = tz.TZDateTime.now(locationFor(zone));
                final day = await showDatePicker(
                  context: context,
                  initialDate: today,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (day == null || !context.mounted) return;
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
                    result = null;
                  });
                }
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: duration,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [15, 30, 45, 60, 90, 120]
                  .map(
                    (n) =>
                        DropdownMenuItem(value: n, child: Text('$n minutes')),
                  )
                  .toList(),
              onChanged: (n) => setState(() {
                duration = n!;
                result = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: room,
              decoration: const InputDecoration(labelText: 'Room (optional)'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('No room'),
                ),
                ...l.rooms.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                ),
              ],
              onChanged: (n) => setState(() {
                room = n;
                result = null;
              }),
            ),
            const SizedBox(height: 16),
            const Text('Participants'),
            ...l.users.map(
              (u) => CheckboxListTile(
                title: Text(u.name),
                value: users.contains(u.id),
                onChanged: (v) => setState(() {
                  v == true ? users.add(u.id) : users.remove(u.id);
                  result = null;
                }),
              ),
            ),
            FilledButton(
              onPressed: busy || start == null
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        result = null;
                      });
                      try {
                        final data =
                            (await ref
                                    .read(apiProvider)
                                    .request(
                                      'availability/check',
                                      method: 'POST',
                                      data: {
                                        'start_time': start!.toIso8601String(),
                                        'end_time': start!
                                            .add(Duration(minutes: duration))
                                            .toIso8601String(),
                                        'room_id': room,
                                        'participant_ids': users.toList(),
                                      },
                                    ))['data']
                                as Json;
                        final participants = (data['participants'] as List)
                            .map((p) => '${p['name']}: ${p['status']}')
                            .join('\n');
                        if (mounted) {
                          setState(
                            () => result =
                                '${data['has_conflicts'] == true ? 'There is a scheduling conflict.' : 'No meeting conflict found.'}\n$participants\nAvailability is checked again when you save.',
                          );
                        }
                      } catch (e) {
                        if (mounted) setState(() => result = e.toString());
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Checking…' : 'Check availability'),
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(result!),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: busy || start == null
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        suggestions = [];
                      });
                      try {
                        final response = await ref
                            .read(apiProvider)
                            .request(
                              'availability/suggestions',
                              query: {
                                'date': DateFormat('yyyy-MM-dd').format(
                                  tz.TZDateTime.from(start!, locationFor(zone)),
                                ),
                                'duration_minutes': duration,
                                'room_id': room,
                                'participant_ids[]': users.toList(),
                              },
                            );
                        if (mounted) {
                          setState(() {
                            suggestions = (response['data'] as List)
                                .map((s) => Slot.fromJson(s as Json))
                                .toList();
                            if (suggestions.isEmpty) {
                              result = 'No alternative slots on this day.';
                            }
                          });
                        }
                      } catch (e) {
                        if (mounted) setState(() => result = e.toString());
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Suggest alternative times'),
            ),
            ...suggestions.map(
              (s) => Card(
                child: ListTile(
                  title: Text(dateLabel(s.start, zone)),
                  trailing: const Icon(Icons.arrow_upward),
                  onTap: () => setState(() {
                    start = s.start.toUtc();
                    result = null;
                    suggestions = [];
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
