import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

const missingRoute = (404, {'message': 'The route api/v1/x could not be found.'});

(Repository, FakeBackend) repository() {
  final backend = FakeBackend();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))..httpClientAdapter = backend;
  return (Repository(Api(client: dio)..token = 't'), backend);
}

void main() {
  setUpAll(prepareWidgetTests);

  group('official production API compatibility', () {
    test('a missing dashboard route is rebuilt from calendar, tasks and notifications', () async {
      final (repo, backend) = repository();
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
      final earlier = (start: dayStart, end: dayStart.add(const Duration(minutes: 1)));
      final soon = (start: nextHour, end: nextHour.add(const Duration(hours: 1)));
      final nextWeek = (start: nextHour.add(const Duration(days: 7)), end: nextHour.add(const Duration(days: 7, hours: 1)));
      String utc(DateTime t) => t.toUtc().toIso8601String();
      Map<String, dynamic> entry(int id, String title, ({DateTime start, DateTime end}) t, {String type = 'meeting', String status = 'scheduled'}) =>
          {'id': id, 'entity_type': type, 'title': title, 'status': status, 'start_time': utc(t.start), 'end_time': utc(t.end)};
      backend.routes['GET dashboard'] = (_) => missingRoute;
      backend.routes['GET calendar/feed'] = (_) => (
        200,
        {
          'data': [
            entry(1, 'Earlier today', earlier),
            entry(2, 'Soon', soon),
            entry(3, 'Cancelled', soon, status: 'cancelled'),
            entry(4, 'Summit', soon, type: 'event'),
            entry(5, 'Next week', nextWeek),
          ],
          'count': 5,
        },
      );
      backend.routes['GET tasks'] = (_) => (200, {'data': [], 'meta': {'total': 5}});
      backend.routes['GET notifications'] = (_) => (200, {'data': [], 'meta': {'total': 9, 'unread_count': 3}});
      final d = await repo.dashboard();

      bool isToday(DateTime t) => t.year == now.year && t.month == now.month && t.day == now.day;
      final counted = [('Earlier today', earlier), ('Soon', soon), ('Next week', nextWeek)];
      final upcoming = [for (final (title, t) in counted) if (t.end.isAfter(now)) title];
      expect(d.today, counted.where((m) => isToday(m.$2.start)).length);
      expect(d.upcoming, upcoming.length);
      expect(d.meetings.map((m) => m.title), upcoming);
      expect(d.meetings.map((m) => m.title), isNot(contains('Cancelled')));
      expect(d.meetings.map((m) => m.title), isNot(contains('Summit')));
      expect(d.tasks, 5);
      expect(d.unread, 3);
      final unread = backend.requests.firstWhere((r) => r.path == 'notifications');
      expect(unread.queryParameters, containsPair('filter', 'unread'));
    });

    test('other dashboard failures are not hidden by the fallback', () async {
      final (repo, backend) = repository();
      backend.routes['GET dashboard'] = (_) => (500, {'message': 'Server Error'});
      await expectLater(repo.dashboard(), throwsA(isA<ApiFailure>().having((e) => e.unsupported, 'unsupported', false)));
    });

    test('a missing lookups route is rebuilt from users, departments, rooms and clients', () async {
      final (repo, backend) = repository();
      backend.routes['GET lookups'] = (_) => missingRoute;
      backend.routes['GET users'] = (_) => (200, {'data': [{'id': 2, 'name': 'Sara', 'role': 'employee'}]});
      backend.routes['GET departments'] = (_) => (200, {'data': [{'id': 1, 'name': 'Engineering', 'code': 'ENG'}]});
      backend.routes['GET rooms'] = (_) => (200, {'data': [{'id': 7, 'name': 'Apollo', 'capacity': 8}]});
      backend.routes['GET clients'] = (_) => (200, {'data': [{'id': 9, 'company_name': 'Acme'}], 'meta': {'total': 1}});
      final l = await repo.lookups();
      expect(l.users.single.name, 'Sara');
      expect(l.departments.single.name, 'Engineering');
      expect(l.rooms.single.id, 7);
      expect(l.clients.single.name, 'Acme');
    });

    test('lookups still work when one of the composed endpoints fails', () async {
      final (repo, backend) = repository();
      backend.routes['GET lookups'] = (_) => missingRoute;
      backend.routes['GET users'] = (_) => (403, {'message': 'Forbidden'});
      backend.routes['GET rooms'] = (_) => (200, {'data': [{'id': 7, 'name': 'Apollo'}]});
      final l = await repo.lookups();
      expect(l.users, isEmpty);
      expect(l.rooms.single.name, 'Apollo');
    });

    test('a 204 No Content reply counts as success', () async {
      final (repo, backend) = repository();
      backend.routes['DELETE meetings/11'] = (_) => (204, null);
      expect(await repo.api.request('meetings/11', method: 'DELETE'), isEmpty);
    });

    test('availability results are read with or without the data wrapper', () {
      expect(resultOf({'has_conflicts': true, 'participants': []})['has_conflicts'], isTrue);
      expect(resultOf({'data': {'has_conflicts': false}})['has_conflicts'], isFalse);
      expect(slotsOf({'slots': [{'start_time': 'a'}], 'count': 1}), hasLength(1));
      expect(slotsOf({'data': [{'start_time': 'a'}, {'start_time': 'b'}]}), hasLength(2));
      expect(slotsOf({}), isEmpty);
    });

    test('official meeting notes with title, content and an action list are readable', () {
      final note = Record.fromJson({
        'id': 3,
        'title': 'Sprint takeaways',
        'content': 'Move Redis to 6380.',
        'action_items': ['Run benchmarks', 'Update env'],
      }, Module.notes);
      expect(note.agenda, 'Sprint takeaways');
      expect(note.discussion, 'Move Redis to 6380.');
      expect(note.actionItems, 'Run benchmarks\nUpdate env');
    });

    test('notification filters send both the documented and the current parameter', () async {
      final (repo, backend) = repository();
      await repo.list(Module.notifications, status: 'unread');
      final r = backend.requests.last;
      expect(r.queryParameters, containsPair('filter', 'unread'));
      expect(r.queryParameters, containsPair('status', 'unread'));
    });
  });

  testWidgets('a room whose detail route is missing shows the record from the list', (tester) async {
    phoneSize(tester, height: 1400);
    final backend = FakeBackend();
    backend.routes['GET rooms/5'] = (_) => missingRoute;
    await tester.pumpWidget(
      harness(
        backend,
        RecordScreen(
          initial: Record.fromJson(
            {'id': 5, 'name': 'Apollo Boardroom', 'location': 'Floor 4', 'capacity': 8, 'is_active': true},
            Module.rooms,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Apollo Boardroom'), findsWidgets);
    expect(find.byType(ErrorPanel), findsNothing);
  });

  testWidgets('a task using the official pending status offers the official status set', (tester) async {
    phoneSize(tester, height: 1400);
    final backend = FakeBackend();
    backend.routes['GET tasks/41'] = (_) => (
      200,
      {
        'data': {'id': 41, 'title': 'Review partition plan', 'status': 'pending', 'priority': 'high', 'can_manage': true},
      },
    );
    await tester.pumpWidget(
      harness(backend, RecordScreen(initial: Record.fromJson({'id': 41, 'title': 'Review'}, Module.tasks))),
    );
    await settle(tester);
    for (final label in ['Pending', 'In Progress', 'Completed']) {
      expect(find.widgetWithText(FilterPill, label), findsOneWidget, reason: label);
    }
    expect(find.widgetWithText(FilterPill, 'Review'), findsNothing);
    await tester.tap(find.widgetWithText(FilterPill, 'Completed'));
    await settle(tester);
    expect(backend.lastWrite()!.data, {'status': 'completed'});
  });
  group('contract v2 shapes', () {
    test('dashboard with a metrics block and no data wrapper', () async {
      final (repo, backend) = repository();
      backend.routes['GET dashboard'] = (_) => (
        200,
        {
          'metrics': {'today_meetings_count': 3, 'upcoming_meetings': 6, 'pending_tasks': 5, 'unread_notifications': 2, 'pending_requests': 1},
          'today_meetings': [
            {'id': 5, 'title': 'Sprint planning', 'start_time': '2026-10-23T09:00:00Z', 'end_time': '2026-10-23T10:00:00Z', 'status': 'scheduled'},
          ],
          'upcoming_meetings': [
            {'id': 5, 'title': 'Sprint planning', 'start_time': '2026-10-23T09:00:00Z', 'end_time': '2026-10-23T10:00:00Z'},
            {'id': 6, 'title': 'Client review', 'start_time': '2026-10-24T09:00:00Z', 'end_time': '2026-10-24T10:00:00Z'},
          ],
          'next_meeting': null,
          'pending_tasks': [
            {'id': 8, 'title': 'Review contract', 'status': 'pending'},
          ],
        },
      );
      final d = await repo.dashboard();
      expect((d.today, d.upcoming, d.tasks), (3, 6, 5));
      // The badge follows the inbox (the fake inbox holds 1 unread), not the
      // dashboard metric (2); see test/inbox_badge_test.dart.
      expect(d.unread, 1);
      expect(d.meetings.map((m) => m.title), ['Sprint planning', 'Client review']);
    });

    test('the current dashboard shape inside data still works', () async {
      final (repo, _) = repository();
      final d = await repo.dashboard();
      expect((d.today, d.upcoming, d.tasks, d.unread), (2, 7, 4, 1));
    });

    test('consolidated lookups without a data wrapper, with clients fetched separately', () async {
      final (repo, backend) = repository();
      backend.routes['GET lookups'] = (_) => (
        200,
        {
          'departments': [{'id': 1, 'name': 'Engineering', 'code': 'ENG'}],
          'rooms': [{'id': 7, 'name': 'Apollo'}],
          'users': [{'id': 2, 'name': 'Sara'}],
          'companies': [{'id': 1, 'name': 'HQ'}],
          'roles': [{'key': 'employee', 'label': 'Team Member'}],
          'task_statuses': [
            for (final s in ['todo', 'pending', 'in_progress', 'review', 'completed', 'cancelled']) {'key': s, 'label': s},
          ],
        },
      );
      backend.routes['GET clients'] = (_) => (200, {'data': [{'id': 9, 'company_name': 'Acme'}]});
      final l = await repo.lookups();
      expect(l.users.single.name, 'Sara');
      expect(l.rooms.single.id, 7);
      expect(l.clients.single.name, 'Acme');
      expect(l.taskStatuses, ['todo', 'pending', 'in_progress', 'review', 'completed', 'cancelled']);
    });

    test('lookups that include clients do not fetch them again', () async {
      final (repo, backend) = repository();
      backend.routes['GET lookups'] = (_) => (200, {'data': {'users': [], 'departments': [], 'rooms': [], 'clients': [{'id': 9, 'name': 'Acme'}]}});
      final l = await repo.lookups();
      expect(l.clients.single.name, 'Acme');
      expect(backend.requests.where((r) => r.path == 'clients'), isEmpty);
      expect(l.taskStatuses, isEmpty);
    });
  });

  testWidgets('task status options follow the server list from lookups', (tester) async {
    phoneSize(tester, height: 1400);
    final backend = FakeBackend();
    backend.routes['GET lookups'] = (_) => (
      200,
      {
        'users': [],
        'departments': [],
        'rooms': [],
        'clients': [],
        'task_statuses': [
          for (final s in ['todo', 'pending', 'in_progress', 'review', 'completed', 'cancelled']) {'key': s, 'label': s},
        ],
      },
    );
    backend.routes['GET tasks/41'] = (_) => (
      200,
      {
        'data': {'id': 41, 'title': 'Review contract', 'status': 'pending', 'can_manage': true},
      },
    );
    await tester.pumpWidget(
      harness(backend, RecordScreen(initial: Record.fromJson({'id': 41, 'title': 'Review'}, Module.tasks))),
    );
    await settle(tester);
    for (final label in ['Todo', 'Pending', 'In Progress', 'Review', 'Completed', 'Cancelled']) {
      expect(find.widgetWithText(FilterPill, label), findsOneWidget, reason: label);
    }
  });
}
