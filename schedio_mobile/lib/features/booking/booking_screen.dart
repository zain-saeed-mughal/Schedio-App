import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final username = TextEditingController();
  final name = TextEditingController(),
      email = TextEditingController(),
      company = TextEditingController(),
      notes = TextEditingController();
  final form = GlobalKey<FormState>();
  BookingProfile? profile;
  List<Slot> slots = [];
  DateTime day = DateTime.now();
  int duration = 30;
  bool busy = false;
  String? error, confirmation, calendarExport;
  Slot? chosen;

  @override
  void initState() {
    super.initState();
    username.text = ref.read(authProvider).value?.bookingUsername ?? '';
  }

  @override
  void dispose() {
    for (final c in [username, name, email, company, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load({bool loadProfile = false}) async {
    setState(() {
      busy = true;
      error = null;
      chosen = null;
      slots = [];
    });
    try {
      final api = ref.read(apiProvider);
      final path = 'public/booking/${Uri.encodeComponent(username.text.trim())}';
      if (loadProfile) {
        final p = BookingProfile.fromJson((await api.request(path))['data'] as Json);
        if (!mounted) return;
        setState(() {
          profile = p;
          duration = p.durations.first;
        });
      }
      final list =
          (await api.request(
                '$path/slots',
                query: {
                  'date': DateFormat('yyyy-MM-dd').format(day),
                  'duration': duration,
                },
              ))['data']
              as List;
      if (mounted) {
        setState(() => slots = list.map((e) => Slot.fromJson(e as Json)).toList());
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> book() async {
    if (!form.currentState!.validate() || chosen == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await ref
          .read(apiProvider)
          .request(
            'public/booking/${Uri.encodeComponent(username.text.trim())}',
            method: 'POST',
            data: {
              'client_name': name.text,
              'client_email': email.text,
              'client_company': company.text,
              'notes': notes.text,
              'start_time': chosen!.start.toUtc().toIso8601String(),
              'duration_minutes': duration,
            },
          );
      ref.read(refreshProvider.notifier).refresh();
      if (mounted) {
        calendarExport = (response['data'] as Json)['calendar_export_url'] as String?;
        haptic(HapticKind.medium);
        setState(() => confirmation = dateLabel(chosen!.start, profile!.timezone));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          chosen = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickDay() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => day = selected);
      load();
    }
  }

  @override
  Widget build(BuildContext context) => GlassPage(
    title: 'Book a Time',
    subtitle: 'Public booking page',
    dim: true,
    body: ListView(
      padding: pageInsets(context),
      children: [
        if (confirmation != null) confirmed() else ...[
          if (profile == null) lookupCard() else ...[
            hostPanel(),
            const SizedBox(height: 16),
            schedulePanel(),
            if (chosen != null) ...[
              const SizedBox(height: 16),
              detailsForm(),
            ],
          ],
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          InlineBanner(message: error!),
        ],
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: SchedioLoadingIndicator()),
        ],
      ],
    ),
  );

  Widget lookupCard() => GlassCard(
    tone: GlassTone.panel,
    blur: true,
    flare: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: GlassTileArt(size: 112, icon: Icons.event_available_rounded)),
        const SizedBox(height: 12),
        Text('Open a booking page', style: AppText.pageTitle, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Preview your public page or book time with a teammate.',
          style: AppText.helper,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppField(
          label: 'Booking username or ID',
          controller: username,
          prefixIcon: Icons.alternate_email_rounded,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => load(loadProfile: true),
        ),
        AppButton(
          label: 'Open booking profile',
          trailingIcon: Icons.arrow_forward_rounded,
          expand: true,
          busy: busy,
          onPressed: () => load(loadProfile: true),
        ),
      ],
    ),
  );

  Widget hostPanel() {
    final p = profile!;
    return GlassCard(
      tone: GlassTone.panel,
      fill: AppColors.panelSplit.withValues(alpha: 0.92),
      accentEdge: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: p.name, size: 64, kind: AvatarKind.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusPill(
                      text: 'Verified Host',
                      tint: Tint.success,
                      icon: Icons.verified_rounded,
                    ),
                    const SizedBox(height: 6),
                    Text(p.name, style: AppText.cardTitle.copyWith(fontSize: 18)),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'Change host',
                size: 38,
                onPressed: () => setState(() {
                  profile = null;
                  slots = [];
                  chosen = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(p.headline, style: AppText.pageTitle),
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.bio, style: AppText.body.copyWith(fontSize: 13)),
          ],
          const SizedBox(height: 18),
          const FieldLabel('Duration'),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in p.durations)
                    SizedBox(
                      width: w,
                      child: SlotPill(
                        label: '${d}m',
                        selected: duration == d,
                        onTap: busy
                            ? null
                            : () {
                                setState(() => duration = d);
                                load();
                              },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _SpecRow(icon: Icons.schedule_rounded, tint: Tint.warning, text: '$duration minute meeting'),
          _SpecRow(icon: Icons.public_rounded, tint: Tint.info, text: 'Times shown in ${p.timezone}'),
          const _SpecRow(
            icon: Icons.event_available_rounded,
            tint: Tint.success,
            text: 'Saved straight to the host calendar',
          ),
        ],
      ),
    );
  }

  Widget schedulePanel() {
    final p = profile!;
    final today = DateTime.now();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM, yyyy').format(day),
                  style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              GlassIconButton(
                icon: Icons.calendar_month_outlined,
                tooltip: 'Pick another date',
                size: 38,
                onPressed: busy ? null : pickDay,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = DateTime(today.year, today.month, today.day + i);
                return DateCard(
                  weekday: DateFormat('EEE').format(d),
                  day: '${d.day}',
                  today: i == 0,
                  selected: d.year == day.year && d.month == day.month && d.day == day.day,
                  onTap: () {
                    if (busy) return;
                    setState(() => day = d);
                    load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.amber400, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('AVAILABLE TIMES', style: AppText.label.copyWith(color: AppColors.slate400)),
              const Spacer(),
              Text(p.timezone, style: AppText.monoTiny),
            ],
          ),
          const SizedBox(height: 12),
          if (slots.isEmpty && !busy)
            const EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No available slots',
              message: 'Try another day or duration.',
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in slots)
                      SizedBox(
                        width: w,
                        child: SlotPill(
                          label: timeLabel(s.start, p.timezone),
                          selected: chosen == s,
                          onTap: busy ? null : () => setState(() => chosen = s),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget detailsForm() => GlassCard(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your details', style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: 'Booking ',
              children: [
                TextSpan(
                  text: dateLabel(chosen!.start, profile!.timezone),
                  style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            style: AppText.helper,
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Your name',
            controller: name,
            required: true,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) => v?.trim().isNotEmpty == true ? null : 'Name is required',
          ),
          AppField(
            label: 'Email',
            controller: email,
            required: true,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                ? null
                : 'Enter a valid email',
          ),
          AppField(
            label: 'Company (optional)',
            controller: company,
            prefixIcon: Icons.apartment_rounded,
          ),
          AppField(label: 'Notes', controller: notes, maxLines: 3),
          AppButton(
            label: 'Confirm booking',
            trailingIcon: Icons.check_rounded,
            expand: true,
            busy: busy,
            onPressed: book,
          ),
        ],
      ),
    ),
  );

  Widget confirmed() => GlassCard(
    tone: GlassTone.panel,
    blur: true,
    flare: true,
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const IconTile(
          icon: Icons.check_rounded,
          tint: Tint.success,
          size: 64,
          iconSize: 32,
          radius: AppRadii.innerAll,
        ),
        const SizedBox(height: 18),
        Text('Booking confirmed', style: AppText.pageTitle),
        const SizedBox(height: 8),
        Text(confirmation!, style: AppText.monoData, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Your meeting is saved in Schedio.', style: AppText.helper),
        const SizedBox(height: 20),
        if (calendarExport != null)
          AppButton(
            label: 'Add to calendar',
            icon: Icons.calendar_month_rounded,
            expand: true,
            onPressed: () async {
              final uri = Uri.tryParse(calendarExport!);
              if (uri != null && uri.scheme == 'https') {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Book another time',
          variant: ButtonVariant.glass,
          expand: true,
          onPressed: () => setState(() {
            confirmation = null;
            chosen = null;
            load();
          }),
        ),
      ],
    ),
  );
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final Tint tint;
  final String text;
  const _SpecRow({required this.icon, required this.tint, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        IconTile(icon: icon, tint: tint, size: 28, iconSize: 15, radius: AppRadii.smallAll),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.helper.copyWith(color: AppColors.slate300))),
      ],
    ),
  );
}
