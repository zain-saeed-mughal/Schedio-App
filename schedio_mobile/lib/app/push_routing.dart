import 'package:flutter/widgets.dart';

import '../core/models.dart';
import '../core/push.dart';
import '../features/workspace/records_screen.dart';

Widget screenForPush(PushMessage message) {
  final type = message.type ?? '';
  final id = message.targetId;
  if (id != null && (type.startsWith('meeting') || type == 'reminder' || type == 'rsvp')) {
    return RecordScreen(
      initial: Record.fromJson({'id': id, 'title': 'Meeting'}, Module.meetings),
    );
  }
  if (id != null && type.startsWith('task')) {
    return RecordScreen(
      initial: Record.fromJson({'id': id, 'title': 'Task'}, Module.tasks),
    );
  }
  return const RecordsScreen(module: Module.notifications);
}
