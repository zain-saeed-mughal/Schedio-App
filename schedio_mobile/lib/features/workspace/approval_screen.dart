import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

final approvalOptionsProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) =>
      ref.watch(apiProvider).request('admin/registration-requests/$id/options'),
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
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review approval')),
    body: AsyncBody(
      value: ref.watch(approvalOptionsProvider(widget.applicant.id)),
      retry: () => ref.invalidate(approvalOptionsProvider(widget.applicant.id)),
      builder: (options) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.applicant.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(widget.applicant.email ?? ''),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'Keep ${label(widget.applicant.role ?? 'employee')}',
                ),
              ),
              for (final value in (options['roles'] as List).cast<String>())
                DropdownMenuItem(value: value, child: Text(label(value))),
            ],
            onChanged: busy ? null : (v) => role = v,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Keep current department'),
              ),
              for (final item in options['departments'] as List)
                DropdownMenuItem(
                  value: item['id'] as int,
                  child: Text(item['name'] as String),
                ),
            ],
            onChanged: busy ? null : (v) => department = v,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: title,
            enabled: !busy,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Job title',
              helperText: 'Leave blank to keep the current title.',
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : approve,
            child: Text(busy ? 'Approving…' : 'Confirm approval'),
          ),
        ],
      ),
    ),
  );
}
