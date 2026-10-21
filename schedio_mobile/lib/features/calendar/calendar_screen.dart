import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../workspace/records_screen.dart';

enum CalendarView { week, month, day, agenda }

extension on CalendarView {
  String get label => switch (this) {
    CalendarView.week => 'Week',
    CalendarView.month => 'Month',
    CalendarView.day => 'Day',
    CalendarView.agenda => 'Agenda',
  };
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime selected, focused;
  CalendarView view = CalendarView.week;

  @override
  void initState() {
    super.initState();
    final now = tz.TZDateTime.now(
      locationFor(ref.read(authProvider).value?.timezone ?? 'UTC'),
    );
    selected = DateTime(now.year, now.month, now.day);
    focused = selected;
  }

  void shift(int direction) => setState(() {
    switch (view) {
      case CalendarView.day:
        selected = DateTime(selected.year, selected.month, selected.day + direction);
        focused = selected;
      case CalendarView.week:
        selected = DateTime(selected.year, selected.month, selected.day + 7 * direction);
        focused = selected;
      case CalendarView.month:
      case CalendarView.agenda:
        focused = DateTime(focused.year, focused.month + direction, 1);
        selected = focused;
    }
  });

  void goToday(tz.Location location) => setState(() {
    final now = tz.TZDateTime.now(location);
    selected = DateTime(now.year, now.month, now.day);
    focused = selected;
  });

  String get rangeTitle => switch (view) {
    CalendarView.day => DateFormat('EEE, MMM d').format(selected),
    CalendarView.week => () {
      final monday = DateTime(selected.year, selected.month, selected.day - selected.weekday + 1);
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return monday.month == sunday.month
          ? '${DateFormat('MMM d').format(monday)} to ${sunday.day}'
          : '${DateFormat('MMM d').format(monday)} to ${DateFormat('MMM d').format(sunday)}';
    }(),
    _ => DateFormat('MMMM yyyy').format(focused),
  };

  @override
  Widget build(BuildContext context) {
    final zone = ref.watch(authProvider).value?.timezone ?? 'UTC';
    final location = locationFor(zone);
    final query = (
      start: tz.TZDateTime(location, focused.year, focused.month, -6),
      end: tz.TZDateTime(location, focused.year, focused.month + 1, 8),
    );
    final value = ref.watch(calendarProvider(query));

    bool onDay(CalendarEntry e, DateTime d) {
      final from = tz.TZDateTime(location, d.year, d.month, d.day);
      final to = tz.TZDateTime(location, d.year, d.month, d.day + 1);
      return e.start.isBefore(to) && e.end.isAfter(from);
    }

    return TabPage(
      title: 'Calendar Hub',
      child: AppRefresh(
        edgeOffset: topChrome(context),
        onRefresh: () async {
          ref.invalidate(calendarProvider(query));
          await ref.read(calendarProvider(query).future);
        },
        child: ListView(
          padding: pageInsets(context, top: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _Header(zone: zone),
            const SizedBox(height: 16),
            SegmentedTabs<CalendarView>(
              selected: view,
              onChanged: (v) => setState(() => view = v),
              segments: [
                for (final v in CalendarView.values) Segment(v, v.label),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                GlassIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous',
                  size: 38,
                  onPressed: () => shift(-1),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    rangeTitle,
                    textAlign: TextAlign.center,
                    style: AppText.pageTitle.copyWith(fontSize: 19, letterSpacing: -0.6),
                  ),
                ),
                const SizedBox(width: 4),
                GlassIconButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next',
                  size: 38,
                  onPressed: () => shift(1),
                ),
                const SizedBox(width: 6),
                _TodayButton(onTap: () => goToday(location)),
              ],
            ),
            const SizedBox(height: 14),
            value.when(
              loading: () => const SizedBox(
                height: 320,
                child: Center(child: SchedioLoadingIndicator()),
              ),
              error: (e, _) => ErrorPanel(
                inline: true,
                message: '$e',
                retry: () => ref.invalidate(calendarProvider(query)),
              ),
              data: (events) {
                final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
                List<CalendarEntry> shown;
                if (view == CalendarView.agenda) {
                  shown = sorted
                      .where((e) => localIn(e.start, zone).month == focused.month ||
                          localIn(e.end, zone).month == focused.month)
                      .toList();
                } else if (view == CalendarView.week) {
                  final monday = DateTime(selected.year, selected.month, selected.day - selected.weekday + 1);
                  final days = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
                  shown = sorted.where((e) => days.any((d) => onDay(e, d))).toList();
                } else {
                  shown = sorted.where((e) => onDay(e, selected)).toList();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (view == CalendarView.week || view == CalendarView.month)
                      GlassCard(
                        tone: GlassTone.panel,
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: constraints.maxWidth.floorToDouble(),
                              child: _StyledCalendar(
                                focused: focused,
                                selected: selected,
                                week: view == CalendarView.week,
                                events: (d) => sorted.where((e) => onDay(e, d)).toList(),
                                onSelect: (s, f) => setState(() {
                                  selected = s;
                                  focused = f;
                                }),
                                onPage: (f) => setState(() => focused = f),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (view == CalendarView.day) ...[
                      if (shown.isEmpty) ...[
                        const EmptyState(
                          icon: Icons.self_improvement_rounded,
                          title: 'A little breathing room',
                          message: 'No scheduled items in this view.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      GlassCard(
                        tone: GlassTone.panel,
                        padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                        child: DayTimeGrid(
                          day: selected,
                          entries: shown,
                          timezone: zone,
                          onTap: (e) => openEntry(context, e),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              view == CalendarView.month
                                  ? dayHeader(selected)
                                  : view == CalendarView.week
                                  ? 'This week'
                                  : 'Agenda',
                              style: AppText.cardTitle.copyWith(fontSize: 17),
                            ),
                          ),
                          Text(zone, style: AppText.monoTiny),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (shown.isEmpty)
                        const EmptyState(
                          icon: Icons.self_improvement_rounded,
                          title: 'A little breathing room',
                          message: 'No scheduled items in this view.',
                        )
                      else
                        _AgendaList(
                          entries: shown,
                          timezone: zone,
                          grouped: view != CalendarView.month,
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void openEntry(BuildContext context, CalendarEntry e) => openRecord(
  context,
  Record.fromJson({'id': e.id, 'title': e.title}, e.module),
);

class _Header extends StatelessWidget {
  final String zone;
  const _Header({required this.zone});

  @override
  Widget build(BuildContext context) => GlassCard(
    tone: GlassTone.panel,
    blur: true,
    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text('Calendar Hub', style: AppText.pageTitle)),
                  const SizedBox(width: 8),
                  const StatusPill(text: 'Interactive', tint: Tint.warning, dot: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(zone, style: AppText.monoTiny.copyWith(color: AppColors.slate400)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<Module>(
          tooltip: 'Create',
          offset: const Offset(0, 52),
          onSelected: (m) => openEditor(context, m),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: Module.meetings,
              child: Row(
                children: [
                  Icon(Icons.videocam_outlined, size: 18, color: AppColors.amber400),
                  SizedBox(width: 10),
                  Text('New meeting'),
                ],
              ),
            ),
            PopupMenuItem(
              value: Module.events,
              child: Row(
                children: [
                  Icon(Icons.celebration_outlined, size: 18, color: AppColors.amber400),
                  SizedBox(width: 10),
                  Text('New event'),
                ],
              ),
            ),
          ],
          child: IgnorePointer(
            child: AppButton(
              label: 'Schedule',
              icon: Icons.add_rounded,
              size: ButtonSize.sm,
              onPressed: () {},
            ),
          ),
        ),
      ],
    ),
  );
}

class _TodayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TodayButton({required this.onTap});

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Today',
    child: GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      onTap: () {
        haptic(HapticKind.selection);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.buttonPress,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF232932).withValues(alpha: 0.8),
          borderRadius: AppRadii.controlAll,
          border: Border.all(
            color: pressed ? AppColors.amber(0.6) : AppColors.white(0.12),
          ),
        ),
        child: Text(
          'Today',
          style: AppText.helper.copyWith(
            fontWeight: FontWeight.w700,
            color: pressed ? AppColors.amber400 : AppColors.slate50,
          ),
        ),
      ),
    ),
  );
}

class _StyledCalendar extends StatelessWidget {
  final DateTime focused, selected;
  final bool week;
  final List<CalendarEntry> Function(DateTime) events;
  final void Function(DateTime, DateTime) onSelect;
  final ValueChanged<DateTime> onPage;
  const _StyledCalendar({
    required this.focused,
    required this.selected,
    required this.week,
    required this.events,
    required this.onSelect,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final dayText = AppText.helper.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.calendarDay,
    );
    return TableCalendar<CalendarEntry>(
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      focusedDay: focused,
      headerVisible: false,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: week ? CalendarFormat.week : CalendarFormat.month,
      availableGestures: AvailableGestures.horizontalSwipe,
      rowHeight: 48,
      daysOfWeekHeight: 26,
      selectedDayPredicate: (d) => isSameDay(d, selected),
      eventLoader: events,
      onDaySelected: onSelect,
      onPageChanged: onPage,
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (d, l) => DateFormat('EEE', l).format(d).toUpperCase(),
        weekdayStyle: AppText.tiny.copyWith(
          fontSize: 11,
          letterSpacing: 0.7,
          color: AppColors.slate400,
        ),
        weekendStyle: AppText.tiny.copyWith(
          fontSize: 11,
          letterSpacing: 0.7,
          color: AppColors.slate500,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        cellMargin: const EdgeInsets.all(5),
        defaultTextStyle: dayText.copyWith(color: AppColors.slate200),
        weekendTextStyle: dayText.copyWith(color: AppColors.slate300),
        outsideTextStyle: dayText.copyWith(color: AppColors.slate600),
        todayTextStyle: dayText.copyWith(
          color: AppColors.amber400,
          fontWeight: FontWeight.w800,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.amber(0.07),
          borderRadius: AppRadii.controlAll,
          border: Border.all(color: AppColors.amber(0.4)),
        ),
        selectedTextStyle: dayText.copyWith(
          color: AppColors.inkOnAmber,
          fontWeight: FontWeight.w800,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.amber500,
          borderRadius: AppRadii.controlAll,
          boxShadow: AppShadows.dateCard,
        ),
        defaultDecoration: const BoxDecoration(borderRadius: AppRadii.controlAll),
        weekendDecoration: const BoxDecoration(borderRadius: AppRadii.controlAll),
        outsideDecoration: const BoxDecoration(borderRadius: AppRadii.controlAll),
        markersMaxCount: 3,
        markerSize: 5,
        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        markersAlignment: Alignment.bottomCenter,
        markerDecoration: const BoxDecoration(
          color: AppColors.amber400,
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, list) => list.isEmpty
            ? null
            : Positioned(
                bottom: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in list.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: e.module == Module.meetings
                              ? AppColors.indigo400
                              : AppColors.blue500,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AgendaList extends StatelessWidget {
  final List<CalendarEntry> entries;
  final String timezone;
  final bool grouped;
  const _AgendaList({
    required this.entries,
    required this.timezone,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? lastDay;
    for (final e in entries) {
      final local = localIn(e.start, timezone);
      final key = DateFormat('yyyy-MM-dd').format(local);
      if (grouped && key != lastDay) {
        lastDay = key;
        children.add(
          Container(
            margin: EdgeInsets.only(top: children.isEmpty ? 0 : 8, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.glassCard.withValues(alpha: 0.9),
              borderRadius: AppRadii.controlAll,
              border: Border.all(color: AppColors.white(0.06)),
            ),
            child: Text(
              dayHeader(local),
              style: AppText.helper.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.slate50,
              ),
            ),
          ),
        );
      }
      children.add(_AgendaRow(entry: e, timezone: timezone));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          StaggeredEntrance(index: i, child: children[i]),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final CalendarEntry entry;
  final String timezone;
  const _AgendaRow({required this.entry, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final meeting = e.module == Module.meetings;
    final color = meeting ? AppColors.eventInternal : AppColors.eventCompany;
    final allDay = e.end.difference(e.start).inHours >= 23;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableRow(
        onTap: () => openEntry(context, e),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDay ? 'ALL DAY' : timeLabel(e.start, timezone),
                    style: AppText.monoData.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!allDay)
                    Text(timeLabel(e.end, timezone), style: AppText.monoTiny),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadii.pill,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: AppText.rowTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    meeting ? 'Meeting' : 'Company event',
                    style: AppText.helper.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              meeting ? Icons.videocam_outlined : Icons.celebration_outlined,
              size: 18,
              color: AppColors.slate500,
            ),
          ],
        ),
      ),
    );
  }
}

class DayTimeGrid extends StatelessWidget {
  final DateTime day;
  final List<CalendarEntry> entries;
  final String timezone;
  final ValueChanged<CalendarEntry> onTap;
  const DayTimeGrid({
    super.key,
    required this.day,
    required this.entries,
    required this.timezone,
    required this.onTap,
  });

  static const startHour = 6;
  static const endHour = 23;
  static const slot = 45.6;
  static const hourHeight = slot * 2;
  static const gutter = 52.0;

  double offsetFor(DateTime local, tz.TZDateTime dayStart) {
    final minutes = local.difference(dayStart).inMinutes - startHour * 60;
    return (minutes / 60 * hourHeight).clamp(0, (endHour - startHour) * hourHeight);
  }

  @override
  Widget build(BuildContext context) {
    final location = locationFor(timezone);
    final dayStart = tz.TZDateTime(location, day.year, day.month, day.day);
    final now = tz.TZDateTime.now(location);
    final isToday = isSameDay(now, day);
    final height = (endHour - startHour) * hourHeight;
    final allDay = entries.where((e) => e.end.difference(e.start).inHours >= 23).toList();
    final timed = entries.where((e) => !allDay.contains(e)).toList();

    final columns = <List<CalendarEntry>>[];
    final columnOf = <CalendarEntry, int>{};
    for (final e in timed) {
      var placed = false;
      for (var c = 0; c < columns.length; c++) {
        if (!columns[c].last.end.isAfter(e.start)) {
          columns[c].add(e);
          columnOf[e] = c;
          placed = true;
          break;
        }
      }
      if (!placed) {
        columns.add([e]);
        columnOf[e] = columns.length - 1;
      }
    }
    final count = columns.isEmpty ? 1 : columns.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: gutter, bottom: 10),
          child: Text(
            DateFormat('EEE d').format(day).toUpperCase(),
            style: AppText.tiny.copyWith(
              fontSize: 11.8,
              letterSpacing: 0.7,
              color: isToday ? AppColors.amber400 : AppColors.slate400,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
        for (final e in allDay)
          Padding(
            padding: const EdgeInsets.only(left: gutter, bottom: 6),
            child: _EventBlock(entry: e, timezone: timezone, compact: true, onTap: () => onTap(e)),
          ),
        SizedBox(
          height: height + 8,
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth - gutter;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isToday)
                    Positioned(
                      left: gutter,
                      right: 0,
                      top: 0,
                      height: height,
                      child: ColoredBox(color: AppColors.amber(0.07)),
                    ),
                  for (var h = startHour; h <= endHour; h++) ...[
                    Positioned(
                      top: (h - startHour) * hourHeight,
                      left: gutter,
                      right: 0,
                      child: Container(height: 1, color: AppColors.white(0.07)),
                    ),
                    if (h < endHour)
                      Positioned(
                        top: (h - startHour) * hourHeight + slot,
                        left: gutter,
                        right: 0,
                        child: Container(height: 1, color: AppColors.white(0.045)),
                      ),
                    Positioned(
                      top: (h - startHour) * hourHeight - 7,
                      left: 0,
                      width: gutter - 8,
                      child: Text(
                        DateFormat('HH:mm').format(DateTime(2000, 1, 1, h)),
                        textAlign: TextAlign.right,
                        style: AppText.monoTiny.copyWith(color: AppColors.calendarDay),
                      ),
                    ),
                  ],
                  for (final e in timed)
                    () {
                      final top = offsetFor(localIn(e.start, timezone), dayStart);
                      final bottom = offsetFor(localIn(e.end, timezone), dayStart);
                      final col = columnOf[e]!;
                      final w = width / count;
                      return Positioned(
                        top: top + 1,
                        left: gutter + col * w + 2,
                        width: w - 4,
                        height: (bottom - top - 2).clamp(24.0, height),
                        child: _EventBlock(entry: e, timezone: timezone, onTap: () => onTap(e)),
                      );
                    }(),
                  if (isToday && now.hour >= startHour && now.hour < endHour)
                    Positioned(
                      top: offsetFor(now, dayStart) - 5,
                      left: gutter - 6,
                      right: 0,
                      child: IgnorePointer(
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 12, color: AppColors.amber500),
                            Expanded(
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppColors.amber500,
                                  boxShadow: [
                                    BoxShadow(color: AppColors.amber(0.8), blurRadius: 10),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventBlock extends StatefulWidget {
  final CalendarEntry entry;
  final String timezone;
  final bool compact;
  final VoidCallback onTap;
  const _EventBlock({
    required this.entry,
    required this.timezone,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends State<_EventBlock> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final color = e.module == Module.meetings ? AppColors.eventInternal : AppColors.eventCompany;
    return Semantics(
      button: true,
      label: e.title,
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.buttonPress,
          curve: AppMotion.signature,
          transform: Matrix4.diagonal3Values(
            pressed ? 1.015 : 1,
            pressed ? 1.015 : 1,
            1,
          )..setTranslationRaw(0, pressed ? -2 : 0, 0),
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: AppRadii.slotAll,
            border: Border.all(color: AppColors.white(0.16)),
            boxShadow: [
              BoxShadow(color: AppColors.black(0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRect(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (e.module == Module.meetings) ...[
                      const Icon(Icons.videocam_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tiny.copyWith(
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!widget.compact)
                  Text(
                    '${timeLabel(e.start, widget.timezone)} to ${timeLabel(e.end, widget.timezone)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoTiny.copyWith(color: AppColors.eventClientText),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
