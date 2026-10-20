import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/shell.dart';
import 'core/providers.dart';
import 'core/widgets.dart';
import 'features/authentication/auth_screen.dart';

export 'app/shell.dart' show WorkspaceShell;

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WorkspaceShell()),
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
  final theme = schedioTheme();

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
    if (auth.value == null || auth.hasError) {
      return MaterialApp(
        title: 'Schedio',
        debugShowCheckedModeBanner: false,
        theme: theme,
        themeMode: ThemeMode.dark,
        home: auth.isLoading
            ? const SplashScreen()
            : auth.hasError
            ? Scaffold(
                backgroundColor: AppColors.bgBase,
                body: Stack(
                  children: [
                    const AmbientBackdrop(),
                    AsyncBody<Object?>(
                      value: auth,
                      retry: () => ref.invalidate(authProvider),
                      builder: (_) => const AuthScreen(),
                    ),
                  ],
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
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.bgBase,
    body: Stack(
      children: [
        AmbientBackdrop(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(size: 64),
              SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
