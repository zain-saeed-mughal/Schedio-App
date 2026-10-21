import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'approval_screen.dart';

ListQuery requestQuery(String status) => (
  module: Module.administration,
  page: 1,
  search: '',
  status: status,
  path: null,
);

bool isCompanyRequest(Record r) => r.role == 'super_admin';

String workspaceLabel(Record r, Account? admin) => isCompanyRequest(r)
    ? 'New company workspace'
    : admin?.company ?? 'Your company';

Future<bool> approveRequest(BuildContext context, Record r) async {
  final approved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => ApprovalScreen(applicant: r)),
  );
  if (approved == true && context.mounted) {
    showToast(context, '${r.title} now has access to the workspace.');
  }
  return approved == true;
}

Future<bool> rejectRequest(
  BuildContext context,
  WidgetRef ref,
  Record r,
  String reason,
) async {
  try {
    await ref
        .read(apiProvider)
        .request(
          'admin/registration-requests/${r.id}/reject',
          method: 'PATCH',
          data: {'rejection_reason': reason},
        );
    ref.read(refreshProvider.notifier).refresh();
    haptic(HapticKind.error);
    if (context.mounted) showToast(context, 'Request from ${r.title} rejected.');
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, '$e', error: true);
    return false;
  }
}

Future<void> askRejection(BuildContext context, WidgetRef ref, Record r) async {
  final value = await showFormSheet<String>(
    context,
    title: 'Reject request',
    subtitle: 'The applicant sees this reason when they try to sign in.',
    builder: (_, fields) => AppField(
      label: 'Rejection reason',
      controller: fields[0],
      labelColor: AppColors.rose400,
      maxLines: 3,
      hint: 'For example, we could not verify your team',
      padding: EdgeInsets.zero,
    ),
    actions: (c, fields) => [
      AppButton(
        label: 'Cancel',
        variant: ButtonVariant.secondary,
        onPressed: () => Navigator.pop(c),
      ),
      AppButton(
        label: 'Confirm Rejection',
        variant: ButtonVariant.danger,
        haptic: HapticKind.error,
        onPressed: () => Navigator.pop(c, fields[0].text.trim()),
      ),
    ],
  );
  if (value != null && context.mounted) {
    await rejectRequest(context, ref, r, value);
  }
}

class RegistrationQueueScreen extends ConsumerStatefulWidget {
  const RegistrationQueueScreen({super.key});

  @override
  ConsumerState<RegistrationQueueScreen> createState() =>
      _RegistrationQueueScreenState();
}

class _RegistrationQueueScreenState
    extends ConsumerState<RegistrationQueueScreen> {
  String status = 'pending';
  String search = '';

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in ['pending', 'approved', 'rejected'])
        s: ref.watch(recordsProvider(requestQuery(s))).value?.total,
    };
    final query = requestQuery(status);
    final admin = ref.watch(authProvider).value;
    return GlassPage(
      title: 'Registration Queue',
      subtitle: 'Review and manage requests',
      body: AppRefresh(
        edgeOffset: topChrome(context),
        onRefresh: () async {
          ref.read(refreshProvider.notifier).refresh();
          await ref.read(recordsProvider(query).future);
        },
        child: ListView(
          padding: pageInsets(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const ScreenHeader(
              title: 'Registration Queue',
              subtitle: 'Review and manage requests',
            ),
            AppSearchField(
              hint: 'Search by name or email',
              onChanged: (v) => setState(() => search = v.toLowerCase()),
            ),
            const SizedBox(height: 14),
            SegmentedTabs<String>(
              selected: status,
              onChanged: (s) => setState(() => status = s),
              segments: [
                Segment('pending', 'Pending', count: counts['pending']),
                Segment('approved', 'Approved', count: counts['approved']),
                Segment('rejected', 'Rejected', count: counts['rejected']),
              ],
            ),
            const SizedBox(height: 18),
            ref.watch(recordsProvider(query)).when(
              loading: () => const SizedBox(
                height: 360,
                child: SkeletonList(count: 3, padding: EdgeInsets.zero),
              ),
              error: (e, _) => ErrorPanel(
                inline: true,
                message: '$e',
                retry: () => ref.invalidate(recordsProvider(query)),
              ),
              data: (page) {
                final items = page.records
                    .where(
                      (r) =>
                          search.isEmpty ||
                          r.title.toLowerCase().contains(search) ||
                          (r.email ?? '').toLowerCase().contains(search),
                    )
                    .toList();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.how_to_reg_outlined,
                    title: search.isEmpty ? 'All caught up' : 'No matches',
                    message: search.isEmpty
                        ? 'There are no ${label(status)} requests right now.'
                        : 'Try another name or email.',
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      StaggeredEntrance(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: RequestCard(
                            record: items[i],
                            workspace: workspaceLabel(items[i], admin),
                            compact: items.length > 1,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RequestCard extends ConsumerWidget {
  final Record record;
  final String workspace;
  final bool compact;
  const RequestCard({
    super.key,
    required this.record,
    required this.workspace,
    this.compact = false,
  });

  void open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RequestDetailScreen(record: record, workspace: workspace),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record;
    final pending = r.status == 'pending';
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          name: r.title,
          kind: isCompanyRequest(r) ? AvatarKind.gold : AvatarKind.staff,
          badgeIcon: isCompanyRequest(r) ? Icons.apartment_rounded : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    r.title,
                    style: AppText.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  pending
                      ? const StatusPill(
                          text: 'Pending Review',
                          tint: Tint(AppColors.amber500, AppColors.amber300),
                        )
                      : StatusPill.status(r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoMuted,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(relativeTime(r.created), style: AppText.monoMuted.copyWith(fontSize: 11)),
            const SizedBox(height: 8),
            GlassIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Open request',
              size: 32,
              round: true,
              onPressed: () => open(context),
            ),
          ],
        ),
      ],
    );

    final tiles = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InfoTile(
            label: 'Company Workspace',
            value: workspace,
            icon: Icons.apartment_rounded,
            accent: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InfoTile(
            label: 'Title and Role',
            value: (r.jobTitle?.isNotEmpty ?? false) ? r.jobTitle! : 'No title given',
            secondary: titleCase(r.role ?? 'employee'),
            icon: Icons.work_outline_rounded,
          ),
        ),
      ],
    );

    final compactRows = Column(
      children: [
        _MetaRow(
          icon: Icons.work_outline_rounded,
          text: [
            if (r.jobTitle?.isNotEmpty ?? false) r.jobTitle!,
            titleCase(r.role ?? 'employee'),
          ].join(' · '),
        ),
        _MetaRow(icon: Icons.apartment_rounded, text: workspace, accent: true),
      ],
    );

    return GlassCard(
      accentEdge: pending,
      sweep: true,
      onTap: () => open(context),
      semanticLabel: 'Registration request from ${r.title}',
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [header, const SizedBox(height: 12), compactRows])),
              ],
            )
          else ...[
            header,
            const SizedBox(height: 14),
            tiles,
          ],
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            InsetWell(
              padding: const EdgeInsets.all(12),
              border: AppColors.slate800,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: AppColors.amber400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.description,
                      maxLines: compact ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.helper.copyWith(
                        color: AppColors.slate300,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    variant: ButtonVariant.danger,
                    icon: Icons.close_rounded,
                    onPressed: () => askRejection(context, ref, r),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    trailingIcon: Icons.arrow_forward_rounded,
                    haptic: HapticKind.medium,
                    onPressed: () => approveRequest(context, r),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool accent;
  const _MetaRow({required this.icon, required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.white(0.05))),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: accent ? AppColors.amber400 : AppColors.slate500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.helper.copyWith(
              color: accent ? AppColors.amber300 : AppColors.slate300,
              fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class RequestDetailScreen extends ConsumerStatefulWidget {
  final Record record;
  final String workspace;
  const RequestDetailScreen({
    super.key,
    required this.record,
    required this.workspace,
  });

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool rejecting = false, busy = false;
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final pending = r.status == 'pending';
    final company = isCompanyRequest(r);
    return GlassPage(
      title: 'Request Detail',
      subtitle: r.email,
      bottomBar: pending ? actionBar(r, company) : null,
      body: ListView(
        padding: pageInsets(context, bottom: pending ? 110 : 24),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                right: -8,
                top: -12,
                child: GlassTileArt(size: 132),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      name: r.title,
                      size: 56,
                      radius: 18,
                      kind: company ? AvatarKind.gold : AvatarKind.staff,
                    ),
                    const SizedBox(height: 14),
                    Text(r.title, style: AppText.screenTitle.copyWith(fontSize: 24)),
                    const SizedBox(height: 8),
                    pending
                        ? const StatusPill(
                            text: 'Pending Review',
                            tint: Tint(AppColors.amber500, AppColors.amber300),
                            size: PillSize.md,
                          )
                        : StatusPill.status(r.status, size: PillSize.md),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (r.email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.amber400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      r.email!,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Workspace and Role', style: AppText.cardTitle),
                const SizedBox(height: 14),
                DetailRow(
                  icon: Icons.apartment_rounded,
                  title: widget.workspace,
                  subtitle: company ? 'Activated together with this CEO account' : 'Company Workspace',
                ),
                DetailRow(
                  icon: Icons.work_outline_rounded,
                  tint: Tint.indigo,
                  title: (r.jobTitle?.isNotEmpty ?? false) ? r.jobTitle! : 'No title given',
                  subtitle: 'Requested role: ${titleCase(r.role ?? 'employee')}',
                ),
              ],
            ),
          ),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '“',
                        style: AppText.hero.copyWith(fontSize: 28, height: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text('User Note', style: AppText.rowTitle),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(r.description, style: AppText.body),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Requested On',
                  value: r.created == null ? 'Unknown' : shortDay(r.created, 'UTC'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: Icons.badge_outlined,
                  label: 'Request Type',
                  value: company ? 'Company CEO' : 'Staff Access',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: titleCase(r.status),
                  accent: pending,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.cardPress,
            curve: AppMotion.signature,
            child: rejecting
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: GlassCard(
                      borderColor: AppColors.rose500.withValues(alpha: 0.35),
                      child: AppField(
                        label: 'Rejection Reason',
                        controller: reason,
                        labelColor: AppColors.rose400,
                        maxLines: 3,
                        hint: 'Shared with the applicant',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget actionBar(Record r, bool company) => rejecting
      ? Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: ButtonVariant.secondary,
                onPressed: busy ? null : () => setState(() => rejecting = false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'Confirm Rejection',
                variant: ButtonVariant.danger,
                busy: busy,
                haptic: HapticKind.error,
                onPressed: () async {
                  setState(() => busy = true);
                  final done = await rejectRequest(context, ref, r, reason.text.trim());
                  if (!mounted) return;
                  setState(() => busy = false);
                  if (done) Navigator.pop(context);
                },
              ),
            ),
          ],
        )
      : Row(
          children: [
            Expanded(
              flex: 4,
              child: AppButton(
                label: 'Reject',
                variant: ButtonVariant.danger,
                onPressed: () => setState(() => rejecting = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 9,
              child: AppButton(
                label: company ? 'Activate & Approve CEO' :'Approve & Grant Access',
                trailingIcon: Icons.arrow_forward_rounded,
                haptic: HapticKind.medium,
                onPressed: () async {
                  final ok = await approveRequest(context, r);
                  if (ok && mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        );
}

class RegistrationQueueBanner extends ConsumerWidget {
  final int pending;
  const RegistrationQueueBanner({super.key, required this.pending});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassCard(
    sweep: true,
    accentEdge: true,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegistrationQueueScreen()),
    ),
    semanticLabel: 'Registration Queue, $pending pending',
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
    child: SizedBox(
      height: 112,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registration Queue', style: AppText.pageTitle),
                const SizedBox(height: 6),
                Text(
                  pending == 0
                      ? 'No one is waiting for approval.'
                      : '$pending ${pending == 1 ? 'person is' : 'people are'} waiting for workspace access.',
                  maxLines: 2,
                  style: AppText.body.copyWith(fontSize: 13),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppGradients.amberButton,
                    borderRadius: AppRadii.controlAll,
                    boxShadow: AppShadows.amberButton,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.inkOnAmber,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const GlassTileArt(size: 104),
        ],
      ),
    ),
  );
}
