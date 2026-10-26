import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'core/firebase_push.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final push = await FirebasePushTransport.create();
  runApp(
    ProviderScope(
      retry: schedioRetry,
      overrides: [if (push != null) pushTransportProvider.overrideWithValue(push)],
      child: const SchedioApp(),
    ),
  );
}
