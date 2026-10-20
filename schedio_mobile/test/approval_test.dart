import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/features/workspace/approval_screen.dart';

import 'mobile_test.dart' show FakeAdapter;

void main() {
  test('applicant name stays distinct from job title and guest metadata survives decoding', () {
    final applicant = Record.fromJson({
      'id': 1,
      'name': 'Applicant',
      'title': 'Engineer',
      'role': 'employee',
    }, Module.administration);
    expect(applicant.title, 'Applicant');
    expect(applicant.jobTitle, 'Engineer');
    final meeting = Record.fromJson({
      'id': 2,
      'title': 'Guest meeting',
      'metadata': {
        'is_client_meeting': true,
        'client_name': 'Guest',
        'client_email': 'guest@example.test',
        'client_company': 'Example',
      },
    }, Module.meetings);
    expect(meeting.isClientMeeting, isTrue);
    expect(meeting.clientName, 'Guest');
    expect(meeting.clientEmail, 'guest@example.test');
    expect(meeting.clientCompany, 'Example');
  });

  testWidgets(
    'approval sends selected role, department and title from server options',
    (tester) async {
      final adapter = FakeAdapter({
        'roles': ['manager', 'employee', 'client'],
        'departments': [
          {'id': 7, 'name': 'Engineering'},
        ],
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiProvider.overrideWithValue(Api(client: dio))],
          child: MaterialApp(
            home: ApprovalScreen(
              applicant: Record.fromJson({
                'id': 4,
                'name': 'Applicant',
                'role': 'employee',
                'approval_status': 'pending',
              }, Module.administration),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('super admin'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('manager').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engineering').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Team lead');
      await tester.ensureVisible(find.text('Confirm approval'));
      await tester.tap(find.text('Confirm approval'));
      await tester.pumpAndSettle();
      expect(adapter.last!.path, 'admin/registration-requests/4/approve');
      expect(adapter.last!.method, 'PATCH');
      expect(adapter.last!.data, {
        'role': 'manager',
        'department_id': 7,
        'title': 'Team lead',
      });
    },
  );
}
