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
      final path =
          'public/booking/${Uri.encodeComponent(username.text.trim())}';
      if (loadProfile) {
        final p = BookingProfile.fromJson(
          (await api.request(path))['data'] as Json,
        );
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
        setState(
          () => slots = list.map((e) => Slot.fromJson(e as Json)).toList(),
        );
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
        calendarExport =
            (response['data'] as Json)['calendar_export_url'] as String?;
        setState(
          () => confirmation = dateLabel(chosen!.start, profile!.timezone),
        );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book a time')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (confirmation != null) ...[
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: 24),
          Text(
            'Booking confirmed',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(confirmation!),
          const SizedBox(height: 16),
          const Text('Your meeting is saved in Schedio.'),
          if (calendarExport != null)
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(calendarExport!);
                if (uri != null && uri.scheme == 'https') {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Add to calendar'),
            ),
        ] else ...[
          TextField(
            controller: username,
            decoration: const InputDecoration(
              labelText: 'Booking username or ID',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : () => load(loadProfile: true),
            child: const Text('Open booking profile'),
          ),
          if (profile != null) ...[
            const SizedBox(height: 24),
            Text(
              profile!.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(profile!.headline),
            Text(profile!.bio),
            const SizedBox(height: 16),
            Text('All slots shown in ${profile!.timezone}'),
            ListTile(
              title: Text(DateFormat.yMMMd().format(day)),
              trailing: const Icon(Icons.calendar_month),
              onTap: busy
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selected != null) {
                        setState(() => day = selected);
                        load();
                      }
                    },
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('${profile!.name}-$duration'),
              initialValue: duration,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: profile!.durations
                  .map(
                    (d) =>
                        DropdownMenuItem(value: d, child: Text('$d minutes')),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (d) {
                      setState(() => duration = d!);
                      load();
                    },
            ),
            const SizedBox(height: 20),
            if (slots.isEmpty && !busy)
              const Text('No available slots. Try another day.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots
                  .map(
                    (s) => ChoiceChip(
                      label: Text(dateLabel(s.start, profile!.timezone)),
                      selected: chosen == s,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => chosen = s),
                    ),
                  )
                  .toList(),
            ),
            if (chosen != null)
              Form(
                key: form,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Your name'),
                      validator: (v) => v?.trim().isNotEmpty == true
                          ? null
                          : 'Name is required',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v ?? '')
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: company,
                      decoration: const InputDecoration(
                        labelText: 'Company (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : book,
                      child: const Text('Confirm booking'),
                    ),
                  ],
                ),
              ),
          ],
        ],
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
