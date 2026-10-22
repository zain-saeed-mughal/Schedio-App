import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../workspace/editor.dart';
import '../workspace/records_screen.dart';

final stageProvider = FutureProvider.autoDispose
    .family<RecordPage, ({String stage, String search})>((ref, q) async {
      ref.watch(refreshProvider);
      ref.watch(authProvider);
      return RecordPage.fromJson(
        await ref
            .watch(apiProvider)
            .request(
              'clients',
              query: {
                'status': q.stage,
                'per_page': 100,
                if (q.search.isNotEmpty) 'search': q.search,
              },
            ),
        Module.clients,
      );
    });

double dealSum(Iterable<Record> records) => records.fold(
  0,
  (sum, r) => sum + (double.tryParse(r.dealValue ?? '') ?? 0),
);

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  bool board = true;
  String search = '';
  String sheetStage = '';
  final overrides = <String, String>{};
  String? dropTarget;

  Future<void> move(Record r, String stage, {Json extra = const {}}) async {
    final from = overrides[r.id] ?? r.status;
    if (from == stage && extra.isEmpty) return;
    setState(() => overrides[r.id] = stage);
    try {
      await ref
          .read(apiProvider)
          .request('clients/${r.id}/status', method: 'PATCH', data: {'status': stage, ...extra});
      if (!mounted) return;
      haptic(HapticKind.medium);
      showToast(context, 'Deal moved successfully!');
      ref.read(refreshProvider.notifier).refresh();
      await Future.wait([
        ref.read(stageProvider((stage: stage, search: search)).future),
        ref.read(stageProvider((stage: from, search: search)).future),
      ]);
      if (mounted) setState(() => overrides.remove(r.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => overrides.remove(r.id));
      haptic(HapticKind.error);
      showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> shiftStage(Record r) async {
    var stage = overrides[r.id] ?? r.status;
    final extra = await showFormSheet<Json>(
      context,
      title: 'Shift Stage',
      subtitle: r.title,
      initial: [r.progress ?? '', r.dealValue ?? '', r.notes ?? ''],
      builder: (c, fields) => StatefulBuilder(
        builder: (c, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Move to stage'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in StageStyle.all)
                  FilterPill(
                    label: s.label,
                    dot: s.dot,
                    selected: stage == s.key,
                    onTap: () => set(() => stage = s.key),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AppField(label: 'Progress note', controller: fields[0], maxLines: 2, maxLength: 500),
            AppField(
              label: 'Deal value',
              controller: fields[1],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.attach_money_rounded,
            ),
            AppField(label: 'Notes', controller: fields[2], maxLines: 3, padding: EdgeInsets.zero),
          ],
        ),
      ),
      actions: (c, fields) => [
        AppButton(
          label: 'Cancel',
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.pop(c),
        ),
        AppButton(
          label: 'Move Deal',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.pop(c, <String, dynamic>{
            for (final (key, field) in [
              ('progress', fields[0]),
              ('deal_value', fields[1]),
              ('notes', fields[2]),
            ])
              if (field.text.trim().isNotEmpty) key: field.text.trim(),
          }),
        ),
      ],
    );
    if (extra != null) await move(r, stage, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final pages = {
      for (final s in StageStyle.all)
        s.key: ref.watch(stageProvider((stage: s.key, search: search))),
    };
    final all = <String, Record>{
      for (final p in pages.values)
        for (final r in p.value?.records ?? const <Record>[]) r.id: r,
    };
    List<Record> inStage(String key) =>
        all.values.where((r) => (overrides[r.id] ?? r.status) == key).toList();
    final loading = pages.values.every((p) => p.isLoading && !p.hasValue);
    final failure = pages.values.where((p) => p.hasError).firstOrNull;
    final account = ref.watch(authProvider).value;
    final height = MediaQuery.sizeOf(context).height;

    return TabPage(
      title: 'Clients and Pipeline',
      child: AppRefresh(
        edgeOffset: topChrome(context),
        onRefresh: () async {
          ref.read(refreshProvider.notifier).refresh();
          await ref.read(stageProvider((stage: 'discovery', search: search)).future);
        },
        child: ListView(
          padding: pageInsets(context, top: 16).copyWith(left: 0, right: 0),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: ScreenHeader(
                title: 'Deal Pipeline',
                subtitle: 'Business development board',
                trailing: AppButton(
                  label: 'Add New Deal',
                  icon: Icons.add_rounded,
                  rotateIcon: true,
                  size: ButtonSize.sm,
                  onPressed: () => openEditor(context, Module.clients),
                ),
              ),
            ),
            SizedBox(
              height: context.textHeight(92, 86),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                itemCount: StageStyle.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final s = StageStyle.all[i];
                  final page = pages[s.key]!.value;
                  final records = inStage(s.key);
                  return _KpiTile(
                    stage: s,
                    count: page == null ? null : records.length + ((page.total - page.records.length).clamp(0, 1 << 30)),
                    sum: dealSum(records),
                    onTap: () => setState(() {
                      board = false;
                      sheetStage = s.key;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Column(
                children: [
                  SegmentedTabs<bool>(
                    selected: board,
                    onChanged: (v) => setState(() => board = v),
                    segments: const [
                      Segment(true, 'Board', icon: Icons.view_kanban_outlined),
                      Segment(false, 'Spreadsheet', icon: Icons.table_rows_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppSearchField(
                    hint: 'Search companies',
                    initial: search,
                    onChanged: (v) => setState(() => search = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: ErrorPanel(
                inline: true,
                  message: '${failure.error}',
                  retry: () => ref.read(refreshProvider.notifier).refresh(),
                ),
              )
            else if (loading)
              const SizedBox(
                height: 360,
                child: Center(child: SchedioLoadingIndicator()),
              )
            else if (board)
              SizedBox(
                height: (height * 0.68).clamp(440.0, 760.0),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                  itemCount: StageStyle.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final s = StageStyle.all[i];
                    final page = pages[s.key]!.value;
                    final records = inStage(s.key);
                    return _Column(
                      stage: s,
                      records: records,
                      more: page == null ? 0 : (page.total - page.records.length).clamp(0, 1 << 30),
                      highlighted: dropTarget == s.key,
                      onHover: (v) => setState(() => dropTarget = v ? s.key : (dropTarget == s.key ? null : dropTarget)),
                      onDrop: (r) {
                        setState(() => dropTarget = null);
                        move(r, s.key);
                      },
                      onShift: shiftStage,
                      onAdd: () => openEditor(context, Module.clients),
                      canManage: (r) => r.canManage || account?.canAdminister == true,
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: _Spreadsheet(
                  records: all.values
                      .where((r) => sheetStage.isEmpty || (overrides[r.id] ?? r.status) == sheetStage)
                      .toList(),
                  stage: sheetStage,
                  onStage: (s) => setState(() => sheetStage = s),
                  overrides: overrides,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final StageStyle stage;
  final int? count;
  final double sum;
  final VoidCallback onTap;
  const _KpiTile({
    required this.stage,
    required this.count,
    required this.sum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressableRow(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    fill: AppColors.slate950.withValues(alpha: 0.6),
    border: AppColors.slate800.withValues(alpha: 0.8),
    child: SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: stage.dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stage.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tiny.copyWith(color: AppColors.slate400, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          Text(count == null ? '-' : '$count', style: AppText.metric.copyWith(fontSize: 22)),
          Text(
            sum > 0 ? money('$sum') : 'No value yet',
            style: AppText.monoTiny.copyWith(color: sum > 0 ? AppColors.amber400 : AppColors.slate500),
          ),
        ],
      ),
    ),
  );
}

class _Column extends StatelessWidget {
  final StageStyle stage;
  final List<Record> records;
  final int more;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final ValueChanged<Record> onDrop;
  final ValueChanged<Record> onShift;
  final VoidCallback onAdd;
  final bool Function(Record) canManage;
  const _Column({
    required this.stage,
    required this.records,
    required this.more,
    required this.highlighted,
    required this.onHover,
    required this.onDrop,
    required this.onShift,
    required this.onAdd,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 56).clamp(260.0, 310.0);
    return DragTarget<Record>(
      onWillAcceptWithDetails: (d) {
        final ok = d.data.status != stage.key;
        if (ok) onHover(true);
        return ok;
      },
      onLeave: (_) => onHover(false),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidate, _) => AnimatedContainer(
        duration: AppMotion.drag,
        curve: Curves.easeOut,
        width: width,
        decoration: BoxDecoration(
          color: highlighted ? Color.alphaBlend(AppColors.amber(0.08), AppColors.columnBg) : AppColors.columnBg,
          borderRadius: AppRadii.cardAll,
          border: Border.all(color: highlighted ? AppColors.amber400 : AppColors.white(0.08)),
          boxShadow: highlighted
              ? [
                  BoxShadow(color: AppColors.amber400.withValues(alpha: 0.3), spreadRadius: 4),
                  BoxShadow(color: AppColors.amber(0.2), blurRadius: 24),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.white(0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.white(0.05), shape: BoxShape.circle),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: stage.dot, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.tiny.copyWith(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            text: '${records.length + more} ${records.length + more == 1 ? 'deal' : 'deals'} - ',
                            children: [
                              TextSpan(
                                text: money('${dealSum(records)}'),
                                style: const TextStyle(color: AppColors.amber400),
                              ),
                              if (more > 0) const TextSpan(text: ' shown'),
                            ],
                          ),
                          style: AppText.monoTiny.copyWith(color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add deal',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.slate400),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: Text(
                          highlighted ? 'Drop to move here' : 'No deals in this stage',
                          style: AppText.helper.copyWith(
                            color: highlighted ? AppColors.amber300 : AppColors.slate500,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length + (more > 0 ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == records.length) {
                          return Center(
                            child: Text('+$more more in Spreadsheet view', style: AppText.monoTiny),
                          );
                        }
                        final r = records[i];
                        final card = _DealCard(
                          record: r,
                          stage: stage,
                          onShift: canManage(r) ? () => onShift(r) : null,
                        );
                        if (!canManage(r)) return card;
                        return LongPressDraggable<Record>(
                          data: r,
                          hapticFeedbackOnStart: true,
                          feedback: Material(
                            type: MaterialType.transparency,
                            child: SizedBox(
                              width: width - 24,
                              child: Transform.rotate(angle: -0.03, child: card),
                            ),
                          ),
                          childWhenDragging: AnimatedScale(
                            scale: 0.95,
                            duration: AppMotion.drag,
                            child: Opacity(opacity: 0.4, child: card),
                          ),
                          child: card,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealCard extends StatefulWidget {
  final Record record;
  final StageStyle stage;
  final VoidCallback? onShift;
  const _DealCard({required this.record, required this.stage, this.onShift});

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final s = widget.stage;
    return Semantics(
      button: true,
      label: '${r.title}, ${s.label}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        onTap: () => openRecord(context, r),
        child: AnimatedContainer(
          duration: AppMotion.drag,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSolid,
            borderRadius: AppRadii.innerAll,
            border: Border.all(color: pressed ? AppColors.amber(0.4) : AppColors.white(0.08)),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(name: r.title, size: 32, kind: AvatarKind.monogram),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.helper.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                        if (r.contactName != null)
                          Text.rich(
                            TextSpan(
                              text: r.contactName,
                              children: [
                                if (r.contactRole != null)
                                  TextSpan(
                                    text: ' · ${r.contactRole}',
                                    style: const TextStyle(color: AppColors.slate400),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.helper.copyWith(fontSize: 11, color: AppColors.slate300),
                          ),
                      ],
                    ),
                  ),
                  if (r.dealValue != null && r.dealValue!.isNotEmpty) ValueChip(value: money(r.dealValue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('PIPELINE FLOW', style: AppText.tiny.copyWith(fontSize: 9.5)),
                  const Spacer(),
                  Text(
                    s.label,
                    style: AppText.tiny.copyWith(color: AppColors.amber400, fontSize: 9.5),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentProgress(step: s.step),
              if (r.campaign != null || r.owner != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (r.campaign != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.slate900,
                          borderRadius: AppRadii.pill,
                          border: Border.all(color: AppColors.slate800),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.track_changes_rounded, size: 11, color: AppColors.indigo300),
                            const SizedBox(width: 4),
                            Text(r.campaign!, style: AppText.tiny.copyWith(color: AppColors.indigo300)),
                          ],
                        ),
                      ),
                    if (r.owner != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.slate400),
                          const SizedBox(width: 3),
                          Text(r.owner!, style: AppText.tiny.copyWith(color: AppColors.slate400)),
                        ],
                      ),
                  ],
                ),
              ],
              if (widget.onShift != null) ...[
                const SizedBox(height: 10),
                AppButton(
                  label: 'Shift Stage',
                  icon: Icons.swap_horiz_rounded,
                  variant: ButtonVariant.glass,
                  size: ButtonSize.sm,
                  expand: true,
                  onPressed: widget.onShift,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Spreadsheet extends StatelessWidget {
  final List<Record> records;
  final String stage;
  final ValueChanged<String> onStage;
  final Map<String, String> overrides;
  const _Spreadsheet({
    required this.records,
    required this.stage,
    required this.onStage,
    required this.overrides,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            for (final s in ['', ...clientStatuses])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterPill(
                  label: s.isEmpty ? 'All stages' : StageStyle.of(s).label,
                  dot: s.isEmpty ? null : StageStyle.of(s).dot,
                  selected: stage == s,
                  onTap: () => onStage(s),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (records.isEmpty)
        const EmptyState(
          icon: Icons.handshake_outlined,
          title: 'No deals here',
          message: 'Try another stage or search.',
        )
      else
        for (var i = 0; i < records.length; i++)
          StaggeredEntrance(
            index: i,
            child: RecordTile(
              record: overrides.containsKey(records[i].id)
                  ? Record.fromJson({
                      'id': records[i].id,
                      'company_name': records[i].title,
                      'status': overrides[records[i].id],
                      'contact_name': records[i].contactName,
                      'contact_role': records[i].contactRole,
                      'deal_value': records[i].dealValue,
                    }, Module.clients)
                  : records[i],
              timezone: 'UTC',
              onTap: () => openRecord(context, records[i]),
            ),
          ),
    ],
  );
}
