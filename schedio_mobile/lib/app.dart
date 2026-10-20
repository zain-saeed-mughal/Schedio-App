import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models.dart';
import 'core/providers.dart';
import 'core/widgets.dart';
import 'features/authentication/auth_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/home_screen.dart';
import 'features/settings/more_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/workspace/records_screen.dart';
import 'theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
          GoRoute(
            path: '/meetings',
            builder: (_, _) => const RecordsScreen(module: Module.meetings),
          ),
          GoRoute(
            path: '/tasks',
            builder: (_, _) => const RecordsScreen(module: Module.tasks),
          ),
          GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class SchedioApp extends ConsumerStatefulWidget {
  const SchedioApp({super.key});
  @override
  ConsumerState<SchedioApp> createState() => _SchedioAppState();
}

class _SchedioAppState extends ConsumerState<SchedioApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authProvider).value != null) {
      ref.read(refreshProvider.notifier).refresh();
      ref.invalidate(authProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = schedioTheme(Brightness.light),
        dark = schedioTheme(Brightness.dark);
    final mode = ref.watch(themeProvider);
    if (auth.value == null || auth.hasError) {
      return MaterialApp(
        title: 'Schedio',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: dark,
        themeMode: mode,
        home: auth.isLoading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : auth.hasError
            ? Scaffold(
                body: AsyncBody<Account?>(
                  value: auth,
                  retry: () => ref.invalidate(authProvider),
                  builder: (_) => const AuthScreen(),
                ),
              )
            : const AuthScreen(),
      );
    }
    return MaterialApp.router(
      key: ValueKey(auth.value!.id),
      title: 'Schedio',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: dark,
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class WorkspaceShell extends StatelessWidget {
  final String path;
  final Widget child;
  const WorkspaceShell({super.key, required this.path, required this.child});
  @override
  Widget build(BuildContext context) {
    const paths = ['/home', '/calendar', '/meetings', '/tasks', '/more'];
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: paths.indexOf(path).clamp(0, 4),
        onDestinationSelected: (i) => context.go(paths[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Meetings',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
