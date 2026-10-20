import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../workspace/records_screen.dart';
import '../availability/availability_screen.dart';
import '../booking/booking_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value!;
    void open(Widget screen) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Your workspace')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: CircleAvatar(child: Text(account.name.substring(0, 1))),
              title: Text(account.name),
              subtitle: Text(
                '${account.company ?? 'Schedio'}\n${label(account.role)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(
                Scaffold(
                  appBar: AppBar(title: const Text('Profile')),
                  body: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        account.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      ...[
                        account.email,
                        account.phone,
                        account.title,
                        account.company,
                        account.department,
                        label(account.role),
                        account.timezone,
                      ].whereType<String>().map(
                        (v) => ListTile(title: Text(v)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final module in [
            Module.clients,
            Module.rooms,
            Module.events,
            Module.notifications,
            if (account.canAdminister) Module.administration,
          ])
            ListTile(
              title: Text(module.label),
              leading: Icon(switch (module) {
                Module.clients => Icons.business_outlined,
                Module.rooms => Icons.meeting_room_outlined,
                Module.events => Icons.event_outlined,
                Module.administration => Icons.admin_panel_settings_outlined,
                _ => Icons.notifications_outlined,
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(RecordsScreen(module: module)),
            ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Availability'),
            onTap: () => open(const AvailabilityScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('Public booking'),
            onTap: () => open(const BookingScreen()),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your booking link',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(account.bookingUrl),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: account.bookingUrl),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Booking link copied'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                text: account.bookingUrl,
                                sharePositionOrigin: const Rect.fromLTWH(
                                  24,
                                  24,
                                  1,
                                  1,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => open(const SettingsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              try {
                await ref.read(authProvider.notifier).logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
