import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassPage(
    title: 'Settings',
    subtitle: 'Notifications and delivery',
    body: ListView(
      padding: pageInsets(context),
      children: [
        const ScreenHeader(
          title: 'Settings',
          subtitle: 'Choose how Schedio keeps you in the loop.',
        ),
        if (ref.watch(authProvider).value == null)
          const Center(child: SchedioLoadingIndicator())
        else
          const NotificationPreferencesPanel(),
      ],
    ),
  );
}

class NotificationPreferencesPanel extends ConsumerStatefulWidget {
  const NotificationPreferencesPanel({super.key});

  @override
  ConsumerState<NotificationPreferencesPanel> createState() =>
      _NotificationPreferencesPanelState();
}

class _NotificationPreferencesPanelState
    extends ConsumerState<NotificationPreferencesPanel> {
  late bool inApp, email;
  late Map<String, ({bool inApp, bool email})> categories;
  bool busy = false, deviceAlerts = false;
  String? message;
  bool failed = false;

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

  Future<void> toggleDeviceAlerts(bool value) async {
    setState(() => busy = true);
    try {
      final account = ref.read(authProvider).value!;
      final service = ref.read(deviceAlertsProvider);
      final enabled = await service.setEnabled(account.id, value);
      if (enabled) {
        await service.sync(ref.read(apiProvider), account);
      }
      if (mounted) setState(() => deviceAlerts = enabled);
    } catch (e, stack) {
      debugPrint('Schedio device alerts failed (${e.runtimeType}: $e)\n$stack');
      if (mounted) {
        setState(() {
          message = friendlyError(e);
          failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
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
              'channels': {'in_app': inApp, 'email': email},
              'categories': {
                for (final e in categories.entries)
                  e.key: {'in_app': e.value.inApp, 'email': e.value.email},
              },
            },
          );
      await ref.read(authProvider.notifier).refreshAccount();
      if (mounted) {
        setState(() => message = null);
        showToast(context, 'Notification preferences saved.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = friendlyError(e);
          failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get pushBuild => ref.read(pushServiceProvider).enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Channels', style: AppText.cardTitle),
            const SizedBox(height: 4),
            Text('Where Schedio can reach you.', style: AppText.helper),
            const SizedBox(height: 16),
            if (pushBuild)
              ValueListenableBuilder<PushStatus>(
                valueListenable: ref.read(pushServiceProvider).status,
                builder: (context, status, _) => SwitchRow(
                  title: 'Push notifications',
                  subtitle: switch (status) {
                    PushStatus.active => 'On for this device. Reminders and updates arrive even when Schedio is closed.',
                    PushStatus.blocked => 'Off. Allow notifications for Schedio in Android settings, then reopen Schedio.',
                    _ => 'Setting up. Schedio is connecting to Google Play services and keeps trying automatically.',
                  },
                  icon: status == PushStatus.active
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_paused_outlined,
                  value: status == PushStatus.active,
                  onChanged: null,
                ),
              )
            else
              SwitchRow(
                title: 'Device alerts',
                subtitle: 'Alerts for new inbox activity when Schedio refreshes.',
                icon: Icons.phone_iphone_rounded,
                value: deviceAlerts,
                onChanged: busy ? null : toggleDeviceAlerts,
              ),
            SwitchRow(
              title: 'In app notifications',
              icon: Icons.notifications_none_rounded,
              value: inApp,
              onChanged: (v) => setState(() => inApp = v),
            ),
            SwitchRow(
              title: 'Email notifications',
              icon: Icons.mail_outline_rounded,
              value: email,
              onChanged: (v) => setState(() => email = v),
              margin: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      if (categories.isNotEmpty) ...[
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Categories', style: AppText.cardTitle),
              const SizedBox(height: 4),
              Text('Fine tune each type of update.', style: AppText.helper),
              const SizedBox(height: 16),
              for (final e in categories.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InsetWell(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleCase(e.key),
                            style: AppText.rowTitle.copyWith(fontSize: 13),
                          ),
                        ),
                        _MiniToggle(
                          label: 'In app',
                          value: e.value.inApp,
                          onChanged: (v) => setState(
                            () => categories[e.key] = (inApp: v, email: e.value.email),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _MiniToggle(
                          label: 'Email',
                          value: e.value.email,
                          onChanged: (v) => setState(
                            () => categories[e.key] = (inApp: e.value.inApp, email: v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (message != null) ...[
        const SizedBox(height: 16),
        InlineBanner(
          message: message!,
          kind: failed ? BannerKind.error : BannerKind.success,
        ),
      ],
      const SizedBox(height: 18),
      AppButton(
        label: busy ? 'Saving...' : 'Save preferences',
        busy: busy,
        expand: true,
        icon: Icons.check_rounded,
        onPressed: save,
      ),
    ],
  );
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => FilterPill(
    label: label,
    selected: value,
    onTap: () => onChanged(!value),
  );
}
