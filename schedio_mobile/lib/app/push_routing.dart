import 'package:flutter/widgets.dart';

import '../core/models.dart';
import '../core/push.dart';
import '../features/workspace/records_screen.dart';

/// The screen a tapped push opens. Meeting events (reminders, invitations,
/// updates, cancellations, responses) open the meeting; task events open the
/// task; anything else, or a push without a target id, opens the inbox.
Widget screenForPush(PushMessage message) {
  final type = (message.type ?? '').toLowerCase();
  final id = message.targetId;
  if (id != null && type.contains('task')) {
    return RecordScreen(
      initial: Record.fromJson({'id': id, 'title': 'Task'}, Module.tasks),
    );
  }
  if (id != null &&
      (type.startsWith('meeting') ||
          type.contains('remind') ||
          type.contains('rsvp') ||
          type.contains('participant') ||
          type.contains('invit'))) {
    return RecordScreen(
      initial: Record.fromJson({'id': id, 'title': 'Meeting'}, Module.meetings),
    );
  }
  return const RecordsScreen(module: Module.notifications);
}
