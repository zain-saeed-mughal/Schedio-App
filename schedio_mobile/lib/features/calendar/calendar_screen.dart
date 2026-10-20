import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../workspace/records_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime selected, focused;
  String view = 'Month';
  @override
  void initState() {
    super.initState();
    selected = tz.TZDateTime.now(
      locationFor(ref.read(authProvider).value?.timezone ?? 'UTC'),
    );
    focused = selected;
  }

  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
    final location = locationFor(zone);
    final query = (
      start: tz.TZDateTime(
        location,
        focused.year,
        focused.month,
        view == 'Week' ? -6 : 1,
      ),
      end: tz.TZDateTime(
        location,
        focused.year,
        focused.month + 1,
        view == 'Week' ? 8 : 1,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              selected = tz.TZDateTime.now(location);
              focused = selected;
            }),
            child: const Text('Today'),
          ),
          PopupMenuButton<Module>(
            onSelected: (m) => openEditor(context, m),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: Module.meetings,
                child: Text('New meeting'),
              ),
              const PopupMenuItem(
                value: Module.events,
                child: Text('New event'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [
                'Month',
                'Week',
                'Day',
                'Agenda',
              ].map((v) => ButtonSegment(value: v, label: Text(v))).toList(),
              selected: {view},
              onSelectionChanged: (v) => setState(() => view = v.first),
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: ref.watch(calendarProvider(query)),
              retry: () => ref.invalidate(calendarProvider(query)),
              builder: (events) {
                bool onDay(CalendarEntry e, DateTime d) {
                  final from = tz.TZDateTime(location, d.year, d.month, d.day);
                  final to = tz.TZDateTime(
                    location,
                    d.year,
                    d.month,
                    d.day + 1,
                  );
                  return e.start.isBefore(to) && e.end.isAfter(from);
                }

                final shown = events.where((e) {
                  if (view == 'Agenda') return true;
                  if (view == 'Week') {
                    final monday = DateTime(
                      selected.year,
                      selected.month,
                      selected.day - selected.weekday + 1,
                    );
                    return List.generate(
                      7,
                      (i) =>
                          DateTime(monday.year, monday.month, monday.day + i),
                    ).any((day) => onDay(e, day));
                  }
                  return onDay(e, selected);
                }).toList()..sort((a, b) => a.start.compareTo(b.start));
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(calendarProvider(query));
                    await ref.read(calendarProvider(query).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (view != 'Agenda' && view != 'Day')
                        LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.topCenter,
                            // Whole logical pixels avoid accumulated PageView
                            // rounding errors across the calendar's date range.
                            child: SizedBox(
                              width: constraints.maxWidth.floorToDouble(),
                              child: TableCalendar<CalendarEntry>(
                                firstDay: DateTime(2000),
                                lastDay: DateTime(2100),
                                focusedDay: focused,
                                calendarFormat: view == 'Week'
                                    ? CalendarFormat.week
                                    : CalendarFormat.month,
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                ),
                                selectedDayPredicate: (d) =>
                                    isSameDay(d, selected),
                                eventLoader: (d) =>
                                    events.where((e) => onDay(e, d)).toList(),
                                onDaySelected: (s, f) => setState(() {
                                  selected = s;
                                  focused = f;
                                }),
                                onPageChanged: (f) =>
                                    setState(() => focused = f),
                              ),
                            ),
                          ),
                        ),
                      if (view == 'Day' || view == 'Agenda')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                selected = view == 'Day'
                                    ? DateTime(
                                        selected.year,
                                        selected.month,
                                        selected.day - 1,
                                      )
                                    : DateTime(
                                        focused.year,
                                        focused.month - 1,
                                        1,
                                      );
                                focused = selected;
                              }),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              view == 'Day'
                                  ? '${selected.day}/${selected.month}/${selected.year}'
                                  : '${focused.month}/${focused.year}',
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                selected = view == 'Day'
                                    ? DateTime(
                                        selected.year,
                                        selected.month,
                                        selected.day + 1,
                                      )
                                    : DateTime(
                                        focused.year,
                                        focused.month + 1,
                                        1,
                                      );
                                focused = selected;
                              }),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Schedule · $zone',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (shown.isEmpty)
                        const EmptyState(
                          title: 'A little breathing room',
                          message: 'No scheduled items in this view.',
                        ),
                      ...shown.map(
                        (e) => Card(
                          child: ListTile(
                            leading: Icon(
                              e.module == Module.meetings
                                  ? Icons.groups_outlined
                                  : Icons.event_outlined,
                            ),
                            title: Text(e.title),
                            subtitle: Text(dateLabel(e.start, zone)),
                            onTap: () => openRecord(
                              context,
                              Record.fromJson({
                                'id': e.id,
                                'title': e.title,
                              }, e.module),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
