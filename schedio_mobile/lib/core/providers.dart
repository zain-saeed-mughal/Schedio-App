import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'device_alerts.dart';
import 'models.dart';

final apiProvider = Provider<Api>((ref) => Api());
final deviceAlertsProvider = Provider((ref) => DeviceAlerts());
final repositoryProvider = Provider(
  (ref) => Repository(ref.watch(apiProvider)),
);
final authProvider = AsyncNotifierProvider<AuthController, Account?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<Account?> {
  @override
  Future<Account?> build() async {
    final api = ref.read(apiProvider);
    api.onSessionExpired = () {
      api.clearToken();
      state = const AsyncData(null);
    };
    await api.restore();
    if (api.token == null) return null;
    try {
      return await ref.read(repositoryProvider).me();
    } on ApiFailure catch (e) {
      if (e.status == 401 || e.status == 403) {
        await api.clearToken();
        if (e.status == 403) rethrow;
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final api = ref.read(apiProvider);
    final result = await api.request(
      'auth/login',
      method: 'POST',
      data: {
        'email': email.trim(),
        'password': password,
        'device_name': 'Schedio mobile',
      },
    );
    await api.saveToken(result['token'] as String);
    state = AsyncData(Account.fromJson(result['user'] as Json));
  }

  Future<void> logout() async {
    await ref.read(apiProvider).request('auth/logout', method: 'POST');
    await ref.read(apiProvider).clearToken();
    state = const AsyncData(null);
  }

  Future<void> refreshAccount() async {
    final api = ref.read(apiProvider);
    final token = api.token;
    final account = await ref.read(repositoryProvider).me();
    if (ref.mounted && token != null && api.token == token) {
      state = AsyncData(account);
    }
  }
}

final refreshProvider = NotifierProvider<RefreshController, int>(
  RefreshController.new,
);

class RefreshController extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

enum ShellTab { home, calendar, meetings, pipeline }

final shellTabProvider = NotifierProvider<ShellTabController, ShellTab>(
  ShellTabController.new,
);

class ShellTabController extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.home;
  void go(ShellTab tab) => state = tab;
}

final dashboardProvider = FutureProvider((ref) async {
  ref.watch(refreshProvider);
  final account = ref.watch(authProvider).value;
  final repository = ref.watch(repositoryProvider);
  final alerts = ref.read(deviceAlertsProvider);
  final dashboard = await repository.dashboard();
  if (account != null) {
    try {
      await alerts.sync(repository.api, account);
    } catch (_) {}
  }
  return dashboard;
});
final lookupsProvider = FutureProvider((ref) {
  ref.watch(refreshProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).lookups();
});
typedef ListQuery = ({
  Module module,
  int page,
  String search,
  String status,
  String? path,
});
final recordsProvider = FutureProvider.autoDispose
    .family<RecordPage, ListQuery>((ref, q) {
      ref.watch(refreshProvider);
      ref.watch(authProvider);
      return ref
          .watch(repositoryProvider)
          .list(
            q.module,
            page: q.page,
            search: q.search,
            status: q.status,
            path: q.path,
          );
    });
final detailProvider = FutureProvider.autoDispose
    .family<Record, ({Module module, String id})>((ref, q) {
      ref.watch(refreshProvider);
      ref.watch(authProvider);
      return ref.watch(repositoryProvider).detail(q.module, q.id);
    });
final calendarProvider = FutureProvider.autoDispose
    .family<List<CalendarEntry>, ({DateTime start, DateTime end})>((ref, q) {
      ref.watch(refreshProvider);
      ref.watch(authProvider);
      return ref.watch(repositoryProvider).calendar(q.start, q.end);
    });
