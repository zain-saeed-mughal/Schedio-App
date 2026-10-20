import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

String label(String value) => value.replaceAll('_', ' ');
tz.Location locationFor(String name) =>
    ['UTC', 'GMT', 'Etc/UTC', 'Etc/GMT'].contains(name)
    ? tz.UTC
    : tz.getLocation(name);
String dateLabel(DateTime? value, String timezone) {
  if (value == null) return '';
  final local = tz.TZDateTime.from(value, locationFor(timezone));
  return '${DateFormat('EEE, d MMM · h:mm a').format(local)} $timezone';
}

class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.retry,
  });
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(e.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: retry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  const EmptyState({super.key, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 54),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class RecordTile extends StatelessWidget {
  final Record record;
  final String timezone;
  final VoidCallback onTap;
  const RecordTile({
    super.key,
    required this.record,
    required this.timezone,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            if (record.start != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(dateLabel(record.start, timezone)),
              ),
            if (record.contactName != null) Text(record.contactName!),
            if (record.owner != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(record.owner!),
              ),
            if (record.description.isNotEmpty &&
                record.module == Module.notifications)
              Text(
                record.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (record.status.isNotEmpty || record.priority != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (record.status.isNotEmpty)
                      Chip(label: Text(label(record.status))),
                    if (record.priority != null)
                      Chip(label: Text(label(record.priority!))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: const Text(
          'This change will also appear in your Schedio workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
