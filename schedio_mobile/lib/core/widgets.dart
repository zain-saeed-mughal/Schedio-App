import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'ui/ui.dart';

export 'ui/ui.dart';

String friendlyError(Object error) {
  if (error is ApiFailure) return error.message;
  if (kDebugMode) debugPrint('Unexpected error: $error');
  if (error is TypeError || error is FormatException) {
    return 'The server sent a response this app could not read. Please try again later.';
  }
  return 'Something went wrong. Please try again.';
}

String label(String value) => value.replaceAll('_', ' ');

String titleCase(String value) => label(value)
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

tz.Location locationFor(String name) =>
    ['UTC', 'GMT', 'Etc/UTC', 'Etc/GMT'].contains(name)
    ? tz.UTC
    : tz.getLocation(name);

tz.TZDateTime localIn(DateTime value, String timezone) =>
    tz.TZDateTime.from(value, locationFor(timezone));

String dateLabel(DateTime? value, String timezone) {
  if (value == null) return '';
  final local = localIn(value, timezone);
  return '${DateFormat('EEE, d MMM · h:mm a').format(local)} $timezone';
}

String timeLabel(DateTime? value, String timezone) =>
    value == null ? '' : DateFormat('h:mm a').format(localIn(value, timezone));

String dayHeader(DateTime value) => DateFormat('EEEE, MMM d').format(value);

String shortDay(DateTime? value, String timezone) =>
    value == null ? '' : DateFormat('EEE, MMM d').format(localIn(value, timezone));

String relativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().toUtc().difference(value.toUtc());
  if (diff.isNegative) return 'soon';
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(value.toLocal());
}

String money(String? value) {
  final n = double.tryParse(value ?? '');
  if (n == null) return value ?? '';
  return NumberFormat.compactSimpleCurrency(locale: 'en_US').format(n);
}

Future<void> openLink(BuildContext context, String? link) async {
  final uri = Uri.tryParse(link ?? '');
  if (uri == null || !['https', 'http'].contains(uri.scheme)) {
    showToast(context, 'This link cannot be opened.', error: true);
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  final Widget? loading;
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.retry,
    this.loading,
  });

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => loading ?? const Center(child: SchedioLoadingIndicator()),
    error: (e, _) => ErrorPanel(message: friendlyError(e), retry: retry),
  );
}

class ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  final bool inline;
  const ErrorPanel({
    super.key,
    required this.message,
    required this.retry,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconTile(
            icon: Icons.cloud_off_rounded,
            tint: Tint.danger,
            size: 56,
            iconSize: 26,
            radius: AppRadii.innerAll,
          ),
          const SizedBox(height: 16),
          Text(
            'We could not load this',
            style: AppText.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(message, style: AppText.helper, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          AppButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: retry,
          ),
        ],
      ),
    );
    if (inline) return card;
    return Center(
      child: SingleChildScrollView(
        padding: pageInsets(context),
        child: Centered(child: card),
      ),
    );
  }
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: switch (record.module) {
      Module.notifications => _NotificationRow(record: record, onTap: onTap),
      _ => GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        radius: AppRadii.innerAll,
        semanticLabel: record.title,
        child: _RecordBody(record: record, timezone: timezone),
      ),
    },
  );
}

class _RecordBody extends StatelessWidget {
  final Record record;
  final String timezone;
  const _RecordBody({required this.record, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final r = record;
    return switch (r.module) {
      Module.meetings => _MeetingBody(record: r, timezone: timezone),
      Module.clients => _ClientBody(record: r),
      _ => _GenericBody(record: r, timezone: timezone),
    };
  }
}

class _MeetingBody extends StatelessWidget {
  final Record record;
  final String timezone;
  const _MeetingBody({required this.record, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final client = r.clientName ?? r.clientCompany;
    final color = r.isClientMeeting ? AppColors.eventClient : AppColors.eventInternal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadii.pill,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.start != null)
                    Text(
                      '${timeLabel(r.start, timezone)}  ·  ${shortDay(r.start, timezone)}',
                      style: AppText.monoData,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    r.title,
                    style: AppText.rowTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (r.status.isNotEmpty)
              StatusPill(
                text: label(r.status),
                tint: meetingStatusTint(r.status),
                dot: true,
              ),
          ],
        ),
        if (client != null || r.owner != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text.rich(
              TextSpan(
                children: [
                  if (client != null) ...[
                    const TextSpan(text: 'Client  '),
                    TextSpan(
                      text: client,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else ...[
                    const TextSpan(text: 'Host  '),
                    TextSpan(
                      text: r.owner,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.helper.copyWith(color: AppColors.slate300),
            ),
          ),
        ],
        if (r.meetingLink != null && r.status != 'cancelled') ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: AppButton(
              label: 'Join Call',
              icon: Icons.videocam_rounded,
              size: ButtonSize.sm,
              variant: ButtonVariant.success,
              onPressed: () => openLink(context, r.meetingLink),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClientBody extends StatelessWidget {
  final Record record;
  const _ClientBody({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final stage = StageStyle.of(r.status);
    return Row(
      children: [
        AppAvatar(name: r.title, size: 40, kind: AvatarKind.monogram),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w800),
              ),
              if (r.contactName != null)
                Text(
                  [r.contactName, r.contactRole].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.helper.copyWith(color: AppColors.slate300),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StageBadge(stage: stage),
                  if (r.dealValue != null && r.dealValue!.isNotEmpty)
                    ValueChip(value: money(r.dealValue)),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
      ],
    );
  }
}

class StageBadge extends StatelessWidget {
  final StageStyle stage;
  const StageBadge({super.key, required this.stage});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: stage.background,
      borderRadius: AppRadii.pill,
      border: Border.all(color: stage.border),
    ),
    child: Text(
      stage.label.toUpperCase(),
      style: AppText.tiny.copyWith(
        color: stage.text,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class ValueChip extends StatelessWidget {
  final String value;
  const ValueChip({super.key, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.amber400.withValues(alpha: 0.1),
      borderRadius: AppRadii.pill,
      border: Border.all(color: AppColors.amber400.withValues(alpha: 0.3)),
    ),
    child: Text(
      value,
      style: AppText.monoTiny.copyWith(color: AppColors.amber300),
    ),
  );
}

class _GenericBody extends StatelessWidget {
  final Record record;
  final String timezone;
  const _GenericBody({required this.record, required this.timezone});

  (IconData, Tint) get look => switch (record.module) {
    Module.tasks => (
      record.status == 'completed'
          ? Icons.task_alt_rounded
          : Icons.radio_button_unchecked_rounded,
      taskStatusTint(record.status),
    ),
    Module.rooms => (Icons.meeting_room_outlined, Tint.indigo),
    Module.events => (Icons.celebration_outlined, eventTint(record.category)),
    Module.notes => (Icons.sticky_note_2_outlined, Tint.purple),
    Module.administration => (Icons.person_add_alt_1_outlined, Tint.warning),
    _ => (Icons.circle_outlined, Tint.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final r = record;
    final (icon, tint) = look;
    final when = r.module == Module.tasks
        ? (r.due == null ? null : 'Due ${shortDay(r.due, timezone)}')
        : r.start == null
        ? (r.due == null ? null : 'Follow up ${shortDay(r.due, timezone)}')
        : '${shortDay(r.start, timezone)}  ·  ${r.isAllDay ? 'All day' : timeLabel(r.start, timezone)}';
    final pills = <Widget>[
      if (r.module == Module.tasks && r.status.isNotEmpty)
        StatusPill(text: label(r.status), tint: taskStatusTint(r.status), dot: true),
      if (r.module == Module.tasks && r.priority != null)
        StatusPill(text: label(r.priority!), tint: priorityTint(r.priority!)),
      if (r.module == Module.events && r.category != null)
        StatusPill(text: label(r.category!), tint: eventTint(r.category)),
      if (r.module == Module.events && r.isCompanyWide)
        const StatusPill(text: 'Company wide', tint: Tint.info),
      if (r.module == Module.rooms)
        StatusPill(
          text: r.isActive ? 'Available' : 'Inactive',
          tint: r.isActive ? Tint.success : Tint.neutral,
          dot: true,
        ),
      if (r.module == Module.rooms && r.capacity != null)
        StatusPill(
          text: '${r.capacity} seats',
          tint: Tint.neutral,
          icon: Icons.people_alt_outlined,
        ),
      if (r.module == Module.administration && r.status.isNotEmpty)
        StatusPill.status(r.status),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon: icon, tint: tint, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowTitle,
              ),
              if (r.module == Module.rooms && r.code != null)
                Text(r.code!, style: AppText.monoMuted.copyWith(fontSize: 11)),
              if (when != null) ...[
                const SizedBox(height: 3),
                Text(when, style: AppText.monoData.copyWith(fontSize: 11)),
              ],
              if (r.module == Module.rooms && r.location != null)
                Text(r.location!, style: AppText.helper),
              if (r.owner != null) ...[
                const SizedBox(height: 3),
                Text(
                  r.owner!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.helper,
                ),
              ],
              if (r.module == Module.rooms && r.amenities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: r.amenities
                      .take(4)
                      .map((a) => StatusPill(text: a, tint: Tint.neutral))
                      .toList(),
                ),
              ],
              if (pills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: pills),
              ],
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.slate500),
      ],
    );
  }
}

Tint eventTint(String? category) => switch (category) {
  'company_holiday' => Tint.success,
  'deadline' => Tint.danger,
  'training' => Tint.indigo,
  'milestone' => Tint.warning,
  'out_of_office' => Tint.purple,
  _ => Tint.info,
};

class _NotificationRow extends StatelessWidget {
  final Record record;
  final VoidCallback onTap;
  const _NotificationRow({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final unread = !r.isRead;
    return Opacity(
      opacity: unread ? 1 : 0.7,
      child: PressableRow(
        onTap: onTap,
        fill: unread ? AppColors.amber400.withValues(alpha: 0.05) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, right: 12),
              width: 12,
              height: 12,
              alignment: Alignment.center,
              decoration: unread
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amber400.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    )
                  : null,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread ? AppColors.amber400 : AppColors.slate600,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: AppText.helper.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate200,
                    ),
                  ),
                  if (r.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.helper,
                    ),
                  ],
                  if (r.owner != null) ...[
                    const SizedBox(height: 4),
                    Text(r.owner!, style: AppText.monoTiny),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
