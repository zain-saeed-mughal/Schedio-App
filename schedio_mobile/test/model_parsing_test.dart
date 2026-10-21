import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/models.dart';

import 'auth_provider_test.dart' show userJson;

void main() {
  test('Laravel empty arrays in object fields do not break parsing', () {
    final meeting = Record.fromJson({
      'id': 5,
      'title': 'Planning',
      'metadata': <dynamic>[],
      'organizer': <dynamic>[],
      'data': <dynamic>[],
    }, Module.meetings);
    expect(meeting.isClientMeeting, isFalse);
    expect(meeting.clientName, isNull);
    expect(meeting.owner, isNull);

    final account = Account.fromJson({
      ...userJson,
      'company': <dynamic>[],
      'department': null,
      'notification_preferences': {
        'channels': {'in_app': true, 'email': false},
        'categories': <dynamic>[],
      },
    });
    expect(account.company, isNull);
    expect(account.preferences.inApp, isTrue);
    expect(account.preferences.categories, isEmpty);
  });

  test('pagination tolerates a missing or empty meta block', () {
    final page = RecordPage.fromJson({
      'data': [
        {'id': 1, 'title': 'Task'},
      ],
      'meta': <dynamic>[],
    }, Module.tasks);
    expect(page.page, 1);
    expect(page.lastPage, 1);
    expect(page.total, 1);
  });
}
