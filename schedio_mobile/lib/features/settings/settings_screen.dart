import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';

final themeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((p) {
      final value = p.getString('appearance');
      if (ref.mounted) {
        state = value == 'light'
            ? ThemeMode.light
            : value == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;
      }
    });
    return ThemeMode.dark;
  }

  Future<void> set(ThemeMode value) async {
    await (await SharedPreferences.getInstance()).setString(
      'appearance',
      value.name,
    );
    state = value;
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool inApp, email;
  late Map<String, ({bool inApp, bool email})> categories;
  bool busy = false, deviceAlerts = false;
  String? message;
  @override
  void initState() {
    super.initState();
    final p = ref.read(authProvider).value!.preferences;
    inApp = p.inApp;
    email = p.email;
    categories = Map.of(p.categories);
    ref
        .read(deviceAlertsProvider)
        .enabled(ref.read(authProvider).value!.id)
        .then((value) {
          if (mounted) setState(() => deviceAlerts = value);
        });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: ThemeMode.values
              .map((m) => ButtonSegment(value: m, label: Text(m.name)))
              .toList(),
          selected: {ref.watch(themeProvider)},
          onSelectionChanged: (v) =>
              ref.read(themeProvider.notifier).set(v.first),
        ),
        const SizedBox(height: 32),
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('Device alerts'),
          subtitle: const Text(
            'Alerts for new inbox activity when Schedio refreshes. Background push is not enabled.',
          ),
          value: deviceAlerts,
          onChanged: busy
              ? null
              : (value) async {
                  setState(() => busy = true);
                  try {
                    final account = ref.read(authProvider).value!;
                    final service = ref.read(deviceAlertsProvider);
                    final enabled = await service.setEnabled(account.id, value);
                    if (enabled) {
                      await service.sync(ref.read(apiProvider), account);
                    }
                    if (mounted) setState(() => deviceAlerts = enabled);
                  } catch (e) {
                    if (mounted) setState(() => message = e.toString());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
        SwitchListTile(
          title: const Text('In-app notifications'),
          value: inApp,
          onChanged: (v) => setState(() => inApp = v),
        ),
        SwitchListTile(
          title: const Text('Email notifications'),
          value: email,
          onChanged: (v) => setState(() => email = v),
        ),
        ...categories.entries.map(
          (e) => Card(
            child: Column(
              children: [
                ListTile(title: Text(label(e.key))),
                SwitchListTile(
                  title: const Text('In app'),
                  value: e.value.inApp,
                  onChanged: (v) => setState(
                    () => categories[e.key] = (inApp: v, email: e.value.email),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Email'),
                  value: e.value.email,
                  onChanged: (v) => setState(
                    () => categories[e.key] = (inApp: e.value.inApp, email: v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    message = null;
                  });
                  try {
                    await ref
                        .read(apiProvider)
                        .request(
                          'notifications/preferences',
                          method: 'POST',
                          data: {
                            'channel_in_app': inApp,
                            'channel_email': email,
                            'categories': {
                              for (final e in categories.entries)
                                e.key: {
                                  'in_app': e.value.inApp,
                                  'email': e.value.email,
                                },
                            },
                          },
                        );
                    await ref.read(authProvider.notifier).refreshAccount();
                    if (mounted) {
                      setState(
                        () => message = 'Notification preferences saved.',
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => message = e.toString());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save preferences'),
        ),
        if (message != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
      ],
    ),
  );
}
