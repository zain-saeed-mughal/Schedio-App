import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/shell.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../booking/booking_screen.dart';
import '../shared/booking_link_card.dart';
import '../workspace/editor.dart';
import '../workspace/records_screen.dart';
import '../workspace/registration_queue.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value;
    if (account == null) return const SizedBox.shrink();
    return TabPage(
      title: "Today's Overview",
      child: AsyncBody(
        value: ref.watch(dashboardProvider),
        retry: () => ref.invalidate(dashboardProvider),
        builder: (d) {
          final now = DateTime.now().toUtc();
          final next = d.meetings
              .where((m) => m.start != null && m.end != null && m.end!.isAfter(now))
              .toList()
            ..sort((a, b) => a.start!.compareTo(b.start!));
          final children = <Widget>[
            _Hero(account: account, today: d.today),
            if (account.canAdminister) const _QueueBannerSlot(),
            BookingLinkCard(
              url: account.bookingUrl,
              onView: () => pushScreen(context, const BookingScreen()),
            ),
            if (next.isNotEmpty) _NextUp(meeting: next.first, timezone: account.timezone),
            _Metrics(dashboard: d),
            _QuickSchedule(timezone: account.timezone),
            SectionHeader(
              title: 'Upcoming Meetings',
              dot: true,
              action: 'View all',
              onAction: () => ref.read(shellTabProvider.notifier).go(ShellTab.meetings),
            ),
            if (d.meetings.isEmpty)
              EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Your schedule is clear',
                message: 'Upcoming meetings will appear here.',
                actionLabel: 'Schedule Meeting',
                onAction: () => openEditor(context, Module.meetings),
              ),
            ...d.meetings.map(
              (r) => RecordTile(
                record: r,
                timezone: account.timezone,
                onTap: () => openRecord(context, r),
              ),
            ),
          ];
          return AppRefresh(
            edgeOffset: topChrome(context),
            onRefresh: () async {
              ref.invalidate(dashboardProvider);
              await ref.read(dashboardProvider.future);
            },
            child: ListView.builder(
              padding: pageInsets(context, top: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: children.length,
              itemBuilder: (_, i) => StaggeredEntrance(
                index: i,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: children[i] is RecordTile || children[i] is SectionHeader
                        ? 0
                        : AppSpace.gap,
                  ),
                  child: children[i],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QueueBannerSlot extends ConsumerWidget {
  const _QueueBannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RegistrationQueueBanner(pending: ref.watch(pendingRequestsProvider).value ?? 0);
}

class _Hero extends ConsumerWidget {
  final Account account;
  final int today;
  const _Hero({required this.account, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = localIn(DateTime.now(), account.timezone).hour;
    final greeting = hour < 12
        ? 'Good Morning,'
        : hour < 17
        ? 'Good Afternoon,'
        : 'Good Evening,';
    return GlassCard(
      tone: GlassTone.panel,
      blur: true,
      flare: true,
      sweep: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
            decoration: BoxDecoration(
              color: AppColors.amber(0.12),
              borderRadius: AppRadii.pill,
              border: Border.all(color: AppColors.amber(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiveDot(size: 6),
                Flexible(
                  child: Text(
                    'Executive Calendar Workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.tiny.copyWith(color: AppColors.amber300, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(greeting, style: AppText.body.copyWith(color: AppColors.slate300)),
          Text(
            '${account.name.split(' ').first} \u{1F44B}',
            style: AppText.cardTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          const Text('Warm welcome:)', style: AppText.hero),
          const SizedBox(height: 8),
          Text(
            today == 0
                ? 'Nothing on the books today. Make space for what matters.'
                : 'You have $today ${today == 1 ? 'meeting' : 'meetings'} today. Here is your day at a glance.',
            style: AppText.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'BD Pipeline',
                icon: Icons.view_kanban_outlined,
                iconColor: AppColors.amber400,
                variant: ButtonVariant.tinted,
                size: ButtonSize.sm,
                onPressed: () => ref.read(shellTabProvider.notifier).go(ShellTab.pipeline),
              ),
              AppButton(
                label: 'Full Calendar',
                icon: Icons.calendar_month_outlined,
                iconColor: AppColors.amber400,
                variant: ButtonVariant.tinted,
                size: ButtonSize.sm,
                onPressed: () => ref.read(shellTabProvider.notifier).go(ShellTab.calendar),
              ),
              AppButton(
                label: 'Book Appointment',
                icon: Icons.add_rounded,
                rotateIcon: true,
                size: ButtonSize.sm,
                onPressed: () => openEditor(context, Module.meetings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  final Record meeting;
  final String timezone;
  const _NextUp({required this.meeting, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final m = meeting;
    final now = DateTime.now().toUtc();
    final live = m.start!.isBefore(now) && m.end!.isAfter(now);
    final mins = m.start!.difference(now).inMinutes;
    final when = live
        ? 'Happening now'
        : mins < 60
        ? 'Starts in ${mins.clamp(1, 59)} min'
        : mins < 1440
        ? 'Starts in ${(mins / 60).floor()}h ${mins % 60}m'
        : shortDay(m.start, timezone);
    return GlassCard(
      accentEdge: true,
      onTap: () => openRecord(context, m),
      semanticLabel: 'Next up: ${m.title}',
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                text: live ? 'Live' : 'Next Up',
                tint: live ? Tint.success : Tint.warning,
                dot: true,
                uppercase: true,
              ),
              const Spacer(),
              Text(when, style: AppText.monoData),
            ],
          ),
          const SizedBox(height: 10),
          Text(m.title, style: AppText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            '${timeLabel(m.start, timezone)} to ${timeLabel(m.end, timezone)}',
            style: AppText.monoMuted,
          ),
          if (m.meetingLink != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AppButton(
                  label: 'Join Call',
                  icon: Icons.videocam_rounded,
                  variant: ButtonVariant.success,
                  size: ButtonSize.sm,
                  onPressed: () => openLink(context, m.meetingLink),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Details',
                  variant: ButtonVariant.glass,
                  size: ButtonSize.sm,
                  onPressed: () => openRecord(context, m),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metrics extends ConsumerWidget {
  final Dashboard dashboard;
  const _Metrics({required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dashboard;
    final cards = [
      MetricCard(
        title: "Today's Schedule",
        value: '${d.today}',
        caption: d.today == 1 ? 'meeting today' : 'meetings today',
        icon: Icons.today_rounded,
        onTap: () => ref.read(shellTabProvider.notifier).go(ShellTab.calendar),
      ),
      MetricCard(
        title: 'Upcoming',
        value: '${d.upcoming}',
        caption: 'scheduled ahead',
        icon: Icons.event_note_rounded,
        tint: Tint.indigo,
        neighbor: AppColors.purple500,
        onTap: () => ref.read(shellTabProvider.notifier).go(ShellTab.meetings),
      ),
      MetricCard(
        title: 'Open Tasks',
        value: '${d.tasks}',
        caption: 'waiting on you',
        icon: Icons.task_alt_rounded,
        tint: Tint.success,
        neighbor: AppColors.cyan500,
        onTap: () => pushScreen(context, const RecordsScreen(module: Module.tasks)),
      ),
      MetricCard(
        title: 'Unread Alerts',
        value: '${d.unread}',
        caption: 'in your inbox',
        icon: Icons.notifications_active_outlined,
        tint: Tint.danger,
        neighbor: AppColors.orange500,
        onTap: () => pushScreen(context, const RecordsScreen(module: Module.notifications)),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

class _QuickSchedule extends StatefulWidget {
  final String timezone;
  const _QuickSchedule({required this.timezone});

  @override
  State<_QuickSchedule> createState() => _QuickScheduleState();
}

class _QuickScheduleState extends State<_QuickSchedule> {
  late tz.TZDateTime today = tz.TZDateTime.now(locationFor(widget.timezone));
  late int dayOffset = today.hour >= 16 && today.minute >= 30 || today.hour >= 17 ? 1 : 0;
  ({int h, int m}) slot = (h: 10, m: 0);

  static final morning = [
    for (var i = 0; i < 6; i++) (h: 9 + i ~/ 2, m: i.isEven ? 0 : 30),
  ];
  static final afternoon = [
    for (var i = 0; i < 6; i++) (h: 14 + i ~/ 2, m: i.isEven ? 0 : 30),
  ];

  tz.TZDateTime at(({int h, int m}) s) => tz.TZDateTime(
    locationFor(widget.timezone),
    today.year,
    today.month,
    today.day + dayOffset,
    s.h,
    s.m,
  );

  bool past(({int h, int m}) s) => at(s).isBefore(tz.TZDateTime.now(locationFor(widget.timezone)));

  String fmt(({int h, int m}) s) =>
      DateFormat('hh:mm a').format(DateTime(2000, 1, 1, s.h, s.m)).toLowerCase();

  Widget grid(String title, List<({int h, int m})> slots) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.amber400, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(title, style: AppText.label.copyWith(color: AppColors.slate400)),
        ],
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in slots)
                SizedBox(
                  width: w,
                  child: Opacity(
                    opacity: past(s) ? 0.35 : 1,
                    child: SlotPill(
                      label: fmt(s),
                      selected: slot == s && !past(s),
                      onTap: past(s) ? null : () => setState(() => slot = s),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final chosen = at(slot);
    final valid = !past(slot);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Schedule', style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Pick a slot to start a meeting draft. Availability is checked when you save.',
            style: AppText.helper,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM, yyyy').format(chosen),
                  style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text(widget.timezone, style: AppText.monoMuted.copyWith(color: AppColors.slate500)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: context.textHeight(64, 32),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = tz.TZDateTime(today.location, today.year, today.month, today.day + i);
                return DateCard(
                  weekday: DateFormat('EEE').format(d),
                  day: '${d.day}',
                  selected: i == dayOffset,
                  today: i == 0,
                  onTap: () => setState(() => dayOffset = i),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          grid('MORNING SLOTS', morning),
          const SizedBox(height: 16),
          grid('AFTERNOON SLOTS', afternoon),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.white(0.06)),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: 'Selected: ',
              children: [
                TextSpan(
                  text: valid
                      ? '${DateFormat('EEE, MMM d').format(chosen)} at ${DateFormat('h:mm a').format(chosen)}'
                      : 'Choose an upcoming slot',
                  style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: AppText.helper.copyWith(color: AppColors.slate300),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Continue with Selected Slot',
            trailingIcon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: valid
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Editor(
                        module: Module.meetings,
                        initialStart: chosen.toUtc(),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
