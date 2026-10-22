import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../availability/availability_screen.dart';
import '../booking/booking_screen.dart';
import '../shared/booking_link_card.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value;
    if (account == null) return const SizedBox.shrink();
    void open(Widget screen) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    final details = [
      (Icons.mail_outline_rounded, account.email, 'Email'),
      if (account.phone != null) (Icons.phone_outlined, account.phone!, 'Phone'),
      if (account.title != null) (Icons.work_outline_rounded, account.title!, 'Title'),
      if (account.department != null)
        (Icons.groups_2_outlined, account.department!, 'Department'),
      (Icons.public_rounded, account.timezone, 'Timezone'),
      (Icons.dns_outlined, '${Env.label} · ${Uri.parse(Env.apiBaseUrl).host}', 'Server'),
    ];
    return GlassPage(
      title: 'Your Profile',
      subtitle: account.company ?? 'Schedio',
      body: ListView(
        padding: pageInsets(context),
        children: [
          GlassCard(
            tone: GlassTone.panel,
            blur: true,
            flare: true,
            sweep: true,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                AppAvatar(
                  name: account.name,
                  size: 72,
                  radius: 22,
                  kind: account.role == 'super_admin' || account.role == 'developer'
                      ? AvatarKind.gold
                      : AvatarKind.staff,
                  ring: true,
                ),
                const SizedBox(height: 14),
                Text(account.name, style: AppText.pageTitle, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                RoleChip(role: account.role),
                if (account.company != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 14, color: AppColors.amber400),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          account.company!,
                          style: AppText.helper.copyWith(
                            color: AppColors.amber300,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Details', style: AppText.cardTitle),
                const SizedBox(height: 14),
                for (final (icon, value, label) in details)
                  DetailRow(icon: icon, title: value, subtitle: label, selectable: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BookingLinkCard(url: account.bookingUrl, onView: () => open(const BookingScreen())),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DetailRow(
                  icon: Icons.event_available_outlined,
                  tint: Tint.success,
                  title: 'Check availability',
                  subtitle: 'Find a time that works for everyone',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                  onTap: () => open(const AvailabilityScreen()),
                ),
                DetailRow(
                  icon: Icons.tune_rounded,
                  tint: Tint.indigo,
                  title: 'Settings',
                  subtitle: 'Notifications and delivery',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
                  onTap: () => open(const SettingsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            variant: ButtonVariant.danger,
            expand: true,
            onPressed: () async {
              try {
                await ref.read(authProvider.notifier).logout();
              } catch (e) {
                if (context.mounted) showToast(context, friendlyError(e), error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}
