import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../workspace/records_screen.dart';
import '../availability/availability_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).value!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedio'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const RecordsScreen(module: Module.notifications),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: AsyncBody(
        value: ref.watch(dashboardProvider),
        retry: () => ref.invalidate(dashboardProvider),
        builder: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            await ref.read(dashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'Hello, ${account.name.split(' ').first}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Make space for what matters.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in [
                    ('Today', d.today),
                    ('Upcoming', d.upcoming),
                    ('Open tasks', d.tasks),
                    ('Unread', d.unread),
                  ])
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 60) / 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${metric.$2}',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                              Text(metric.$1),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => openEditor(context, Module.meetings),
                icon: const Icon(Icons.add),
                label: const Text('Schedule a meeting'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AvailabilityScreen(),
                  ),
                ),
                icon: const Icon(Icons.schedule),
                label: const Text('Check availability'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coming up',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => context.go('/meetings'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (d.meetings.isEmpty)
                const EmptyState(
                  title: 'Your schedule is clear',
                  message: 'Upcoming meetings will appear here.',
                ),
              ...d.meetings.map(
                (r) => RecordTile(
                  record: r,
                  timezone: account.timezone,
                  onTap: () => openRecord(context, r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
