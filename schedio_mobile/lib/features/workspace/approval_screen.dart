import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

final approvalOptionsProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) async => resultOf(
    await ref.watch(apiProvider).request('admin/registration-requests/$id/options'),
  ),
);

class ApprovalScreen extends ConsumerStatefulWidget {
  final Record applicant;
  const ApprovalScreen({super.key, required this.applicant});
  @override
  ConsumerState<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends ConsumerState<ApprovalScreen> {
  late final title = TextEditingController(
    text: widget.applicant.jobTitle ?? '',
  );
  String? role;
  int? department;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> approve() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .request(
            'admin/registration-requests/${widget.applicant.id}/approve',
            method: 'PATCH',
            data: {
              if (role != null) 'role': role,
              if (department != null) 'department_id': department,
              if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
            },
          );
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.applicant;
    final ready = ref.watch(approvalOptionsProvider(a.id)).hasValue;
    return GlassPage(
      title: 'Review approval',
      subtitle: a.email,
      bottomBar: AppButton(
        label: busy ? 'Approving' : 'Confirm approval',
        trailingIcon: busy ? null : Icons.check_rounded,
        busy: busy,
        expand: true,
        haptic: HapticKind.medium,
        onPressed: ready ? approve : null,
      ),
      body: AsyncBody(
        value: ref.watch(approvalOptionsProvider(a.id)),
        retry: () => ref.invalidate(approvalOptionsProvider(a.id)),
        builder: (options) => ListView(
          padding: pageInsets(context, bottom: 110),
          children: [
            GlassCard(
              accentEdge: true,
              child: Row(
                children: [
                  AppAvatar(
                    name: a.title,
                    size: 52,
                    kind: a.role == 'super_admin'
                        ? AvatarKind.gold
                        : AvatarKind.staff,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: AppText.pageTitle),
                        const SizedBox(height: 2),
                        Text(a.email ?? '', style: AppText.monoMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Access settings', style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust the role, department or title before granting access.',
                    style: AppText.helper,
                  ),
                  const SizedBox(height: 18),
                  AppDropdown<String>(
                    label: 'Role',
                    value: null,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('Keep ${titleCase(a.role ?? 'employee')}'),
                      ),
                      for (final r in options['roles'] is List ? options['roles'] as List : const [])
                        if ((r is String ? r : asMap(r)?['key'] as String?) case final String value)
                          DropdownMenuItem(
                            value: value,
                            child: Text(r is Map && r['label'] is String ? r['label'] as String : titleCase(value)),
                          ),
                    ],
                    onChanged: busy ? null : (v) => role = v,
                  ),
                  AppDropdown<int>(
                    label: 'Department',
                    value: null,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Keep current department'),
                      ),
                      for (final item in options['departments'] is List ? options['departments'] as List : const [])
                        if (asInt(item) case final int id)
                          DropdownMenuItem(
                            value: id,
                            child: Text(nameOf(item) ?? 'Department $id'),
                          ),
                    ],
                    onChanged: busy ? null : (v) => department = v,
                  ),
                  AppField(
                    label: 'Job title',
                    controller: title,
                    enabled: !busy,
                    maxLength: 150,
                    prefixIcon: Icons.work_outline_rounded,
                    helper: 'Leave blank to keep the current title.',
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              InlineBanner(message: error!),
            ],
          ],
        ),
      ),
    );
  }
}
