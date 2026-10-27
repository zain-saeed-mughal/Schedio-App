import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../core/push.dart';
import '../core/widgets.dart';
import '../features/availability/availability_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/dashboard/home_screen.dart';
import '../features/pipeline/pipeline_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/workspace/editor.dart';
import '../features/workspace/records_screen.dart';
import '../features/workspace/registration_queue.dart';
import 'nav_bar.dart';
import 'push_routing.dart';

final pendingRequestsProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(refreshProvider);
  final account = ref.watch(authProvider).value;
  if (account == null || !account.canAdminister) return 0;
  final page = await ref
      .watch(repositoryProvider)
      .list(Module.administration, status: 'pending');
  return page.total;
});

void pushScreen(BuildContext context, Widget screen) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => screen),
);

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final transition =
      AnimationController(vsync: this, duration: AppMotion.page, value: 1)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => previous = null);
          }
        });
  ShellTab? previous;
  final visited = <ShellTab>{ShellTab.home};
  bool sheetOpen = false;
  Timer? poll;

  static const destinations = [
    NavDestination('Home', Icons.home_outlined, Icons.home_rounded),
    NavDestination(
      'Calendar',
      Icons.calendar_today_outlined,
      Icons.calendar_month_rounded,
    ),
    NavDestination('Meetings', Icons.videocam_outlined, Icons.videocam_rounded),
    NavDestination(
      'Pipeline',
      Icons.view_kanban_outlined,
      Icons.view_kanban_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startPolling();
    final push = ref.read(pushServiceProvider)
      ..onOpen = openFromPush
      // A push while the app is open: refresh the inbox, badge and lists
      // so a new persistent notification shows without a manual refresh.
      ..onForeground = (message) {
        ref.read(refreshProvider.notifier).refresh();
      };
    unawaited(push.start().catchError((Object e) {
      debugPrint('Schedio push registration failed (${e.runtimeType}: ${e is ApiFailure ? 'HTTP ${e.status} ${e.message}' : e})');
    }));
  }

  void openFromPush(PushMessage message) {
    if (!mounted) return;
    ref.read(refreshProvider.notifier).refresh();
    final id = message.notificationId;
    if (id != null) {
      unawaited(
        ref
            .read(apiProvider)
            .request('notifications/$id/read', method: 'PATCH')
            // Refresh again once the server has it, so the badge drops.
            .then<void>(
              (_) {
                if (mounted) ref.read(refreshProvider.notifier).refresh();
              },
              onError: (Object _) {},
            ),
      );
    }
    pushScreen(context, screenForPush(message));
  }

  void startPolling() {
    poll?.cancel();
    poll = Timer.periodic(AppMotion.poll, (_) {
      if (mounted) ref.invalidate(dashboardProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startPolling();
      final push = ref.read(pushServiceProvider);
      unawaited(push.status.value == PushStatus.blocked ? push.start() : push.retryNow());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      poll?.cancel();
      poll = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    transition.dispose();
    super.dispose();
  }

  void select(ShellTab tab) {
    final current = ref.read(shellTabProvider);
    if (tab == current) return;
    ref.read(shellTabProvider.notifier).go(tab);
  }

  void onTabChanged(ShellTab? from, ShellTab to) {
    setState(() {
      previous = from;
      visited.add(to);
    });
    transition.duration = AppMotion.reduced(context)
        ? AppMotion.reducedFade
        : AppMotion.page;
    transition.forward(from: 0);
  }

  Future<void> openQuickActions() async {
    setState(() => sheetOpen = true);
    await showAppSheet<void>(
      context,
      title: 'Quick Actions',
      subtitle: 'Jump anywhere in your workspace',
      builder: (c) => QuickActionsGrid(
        onOpen: (screen) {
          Navigator.pop(c);
          if (screen != null) pushScreen(context, screen);
        },
      ),
    );
    if (mounted) setState(() => sheetOpen = false);
  }

  Widget tabScreen(ShellTab tab) => switch (tab) {
    ShellTab.home => const HomeScreen(),
    ShellTab.calendar => const CalendarScreen(),
    ShellTab.meetings => const RecordsScreen(module: Module.meetings),
    ShellTab.pipeline => const PipelineScreen(),
  };

  Widget layer(ShellTab tab, ShellTab current) {
    final isCurrent = tab == current;
    final isPrevious = tab == previous && transition.isAnimating;
    if (!visited.contains(tab)) return const SizedBox.shrink();
    final direction = previous == null
        ? 0.0
        : (current.index - previous!.index).sign.toDouble();
    final reduced = AppMotion.reduced(context);
    return Positioned.fill(
      child: Offstage(
        offstage: !isCurrent && !isPrevious,
        child: TickerMode(
          enabled: isCurrent,
          child: AnimatedBuilder(
            animation: transition,
            builder: (context, child) {
              final t = transition.value;
              double opacity, dx;
              if (isCurrent) {
                final e = AppMotion.signature.transform(t);
                opacity = e;
                dx = reduced ? 0 : direction * 0.12 * (1 - e);
              } else if (isPrevious) {
                final outT = (t * AppMotion.page.inMilliseconds /
                        AppMotion.pageOut.inMilliseconds)
                    .clamp(0.0, 1.0);
                final e = AppMotion.signature.transform(outT);
                opacity = 1 - e;
                dx = reduced ? 0 : -direction * 0.06 * e;
              } else {
                opacity = 1;
                dx = 0;
              }
              return IgnorePointer(
                ignoring: !isCurrent,
                child: FractionalTranslation(
                  translation: Offset(dx, 0),
                  child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
                ),
              );
            },
            child: KeyedSubtree(
              key: PageStorageKey(tab),
              child: tabScreen(tab),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellTabProvider, onTabChanged);
    final tab = ref.watch(shellTabProvider);
    final account = ref.watch(authProvider).value;
    if (account == null) return const ColoredBox(color: AppColors.bgBase);
    final unread = ref.watch(dashboardProvider).value?.unread ?? 0;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBody: true,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: ShellTopBar(
        tab: tab,
        account: account,
        unread: unread,
        onBell: () => pushScreen(
          context,
          const RecordsScreen(module: Module.notifications),
        ),
        onProfile: () => pushScreen(context, const ProfileScreen()),
      ),
      bottomNavigationBar: NotchedNavBar(
        items: destinations,
        current: tab.index,
        hidden: keyboard,
        fabOpen: sheetOpen,
        onFab: openQuickActions,
        onSelect: (i) => select(ShellTab.values[i]),
      ),
      body: ShellChrome(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AmbientBackdrop(),
            for (final t in ShellTab.values) layer(t, tab),
          ],
        ),
      ),
    );
  }
}

class ShellTopBar extends StatelessWidget implements PreferredSizeWidget {
  final ShellTab tab;
  final Account account;
  final int unread;
  final VoidCallback onBell;
  final VoidCallback onProfile;
  const ShellTopBar({
    super.key,
    required this.tab,
    required this.account,
    required this.unread,
    required this.onBell,
    required this.onProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpace.topBar);

  String get title => switch (tab) {
    ShellTab.home => "Today's Overview",
    ShellTab.calendar => 'Calendar Hub',
    ShellTab.meetings => 'My Meetings',
    ShellTab.pipeline => 'Clients and Pipeline',
  };

  @override
  Widget build(BuildContext context) => GlassTopBar(
    leading: const BrandLogo(size: 38),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.popoverIn,
          child: Text(
            title,
            key: ValueKey(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Row(
          children: [
            const LiveDot(size: 5),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                DateFormat('EEEE, MMM d').format(
                  localIn(DateTime.now(), account.timezone),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoTiny.copyWith(color: AppColors.slate400),
              ),
            ),
          ],
        ),
      ],
    ),
    actions: [
      GlassIconButton(
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notifications',
        badge: unread,
        onPressed: onBell,
      ),
      Semantics(
        button: true,
        label: 'Your profile',
        child: GestureDetector(
          onTap: onProfile,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AppAvatar(
                name: account.name,
                size: 34,
                radius: 12,
                kind: AvatarKind.soft,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class QuickAction {
  final String label;
  final IconData icon;
  final Widget? Function() screen;
  final int badge;
  final bool primary;
  const QuickAction(
    this.label,
    this.icon,
    this.screen, {
    this.badge = 0,
    this.primary = false,
  });
}

class QuickActionsGrid extends ConsumerWidget {
  final void Function(Widget? screen) onOpen;
  const QuickActionsGrid({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value;
    if (account == null) return const SizedBox.shrink();
    final unread = ref.watch(dashboardProvider).value?.unread ?? 0;
    final pending = account.canAdminister
        ? ref.watch(pendingRequestsProvider).value ?? 0
        : 0;
    final actions = [
      QuickAction(
        'Schedule Meeting',
        Icons.add_rounded,
        () => const Editor(module: Module.meetings),
        primary: true,
      ),
      QuickAction(
        'Reminders and Alerts',
        Icons.notifications_active_outlined,
        () => const RecordsScreen(module: Module.notifications),
        badge: unread,
      ),
      QuickAction(
        'My Tasks',
        Icons.task_alt_rounded,
        () => const RecordsScreen(module: Module.tasks),
      ),
      QuickAction(
        'Meeting Suites',
        Icons.meeting_room_outlined,
        () => const RecordsScreen(module: Module.rooms),
      ),
      QuickAction(
        'Events and Holidays',
        Icons.celebration_outlined,
        () => const RecordsScreen(module: Module.events),
      ),
      QuickAction(
        'Check Availability',
        Icons.event_available_outlined,
        () => const AvailabilityScreen(),
      ),
      QuickAction(
        'My Booking Page',
        Icons.link_rounded,
        () => const BookingScreen(),
      ),
      if (account.canAdminister)
        QuickAction(
          'Registration Queue',
          Icons.how_to_reg_outlined,
          () => const RegistrationQueueScreen(),
          badge: pending,
        ),
      QuickAction(
        'Settings',
        Icons.tune_rounded,
        () => const SettingsScreen(),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < actions.length; i++)
                  SizedBox(
                    width: width,
                    child: StaggeredEntrance(
                      index: i,
                      child: _QuickTile(
                        action: actions[i],
                        onTap: () => onOpen(actions[i].screen()),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceDeep,
            borderRadius: AppRadii.innerAll,
            border: Border.all(color: AppColors.white(0.06)),
          ),
          child: Row(
            children: [
              AppAvatar(
                name: account.name,
                size: 36,
                radius: 12,
                kind: AvatarKind.soft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowTitle,
                    ),
                    Text(
                      titleCase(
                        account.role == 'client' ? 'Client Partner' : account.role,
                      ),
                      style: AppText.monoTiny.copyWith(color: AppColors.amber400),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                iconColor: AppColors.rose400,
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                onPressed: () async {
                  final auth = ref.read(authProvider.notifier);
                  final messenger = Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);
                  try {
                    await auth.logout();
                  } catch (e) {
                    if (messenger.mounted) {
                      showToast(messenger, friendlyError(e), error: true);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    radius: AppRadii.innerAll,
    semanticLabel: action.label,
    child: Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: AppRadii.controlAll,
                gradient: action.primary ? AppGradients.amberButton : null,
                color: action.primary ? null : AppColors.amber400.withValues(alpha: 0.1),
                border: Border.all(
                  color: action.primary
                      ? Colors.transparent
                      : AppColors.amber400.withValues(alpha: 0.3),
                ),
                boxShadow: action.primary ? AppShadows.amberButton : null,
              ),
              child: Icon(
                action.icon,
                size: 20,
                color: action.primary ? AppColors.inkOnAmber : AppColors.amber400,
              ),
            ),
            if (action.badge > 0)
              Positioned(
                top: -6,
                right: -6,
                child: CountBadge(count: action.badge, ring: AppColors.modalSurface),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            action.label,
            maxLines: 2,
            style: AppText.helper.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
