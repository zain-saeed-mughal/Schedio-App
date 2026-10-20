import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool register = false, company = false, busy = false, obscure = true;
  String? error, accountStatus;
  int? companyId, departmentId;
  List<Member> companies = [];
  List<({int id, int companyId, String name})> departments = [];

  TextEditingController field(String key) =>
      fields.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> options() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final j =
          (await ref
                  .read(apiProvider)
                  .request('auth/registration-options'))['data']
              as Json;
      if (!mounted) return;
      setState(() {
        companies = (j['companies'] as List)
            .map((e) => Member.fromJson(e as Json))
            .toList();
        departments = (j['departments'] as List)
            .map(
              (e) => (
                id: e['id'] as int,
                companyId: e['company_id'] as int,
                name: e['name'] as String,
              ),
            )
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await ref
            .read(apiProvider)
            .request(
              'auth/register',
              method: 'POST',
              data: {
                for (final e in fields.entries) e.key: e.value.text,
                'registration_type': company
                    ? 'company_super_admin'
                    : 'employee',
                if (!company) 'company_id': companyId,
                if (!company) 'department_id': departmentId,
              },
            );
        if (mounted) setState(() => accountStatus = 'pending');
      } else {
        await ref
            .read(authProvider.notifier)
            .login(field('email').text, field('password').text);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          accountStatus = e.accountStatus;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggleMode() {
    setState(() {
      register = !register;
      error = null;
    });
    if (register) options();
  }

  Widget input(
    String key,
    String title, {
    bool required = false,
    bool password = false,
    bool highlighted = false,
    IconData? icon,
    int lines = 1,
    String? hint,
  }) => AppField(
    label: title,
    controller: field(key),
    required: required,
    highlighted: highlighted,
    obscure: password && obscure,
    maxLines: lines,
    hint: hint,
    prefixIcon: icon,
    keyboardType: key == 'email'
        ? TextInputType.emailAddress
        : key == 'phone'
        ? TextInputType.phone
        : TextInputType.text,
    autofillHints: key == 'email'
        ? const [AutofillHints.email]
        : password
        ? const [AutofillHints.password]
        : null,
    suffix: password
        ? IconButton(
            tooltip: obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => obscure = !obscure),
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
          )
        : null,
    validator: (v) {
      if (required && (v == null || v.trim().isEmpty)) {
        return '$title is required';
      }
      if (key == 'email' &&
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')) {
        return 'Enter a valid email';
      }
      if (key == 'password_confirmation' && v != field('password').text) {
        return 'Passwords do not match';
      }
      return null;
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgBase,
    body: Stack(
      children: [
        const AmbientBackdrop(dim: true),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: accountStatus != null ? statusGate() : authForm(),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget brandHeader() => Column(
    children: [
      const BrandLogo(size: 84),
      const SizedBox(height: 18),
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: SchedioWordmark(fontSize: 30),
      ),
      const SizedBox(height: 10),
      const BrandTagline(fontSize: 10.5, spacing: 3.6),
    ],
  );

  Widget authForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      brandHeader(),
      const SizedBox(height: 32),
      GlassCard(
        tone: GlassTone.panel,
        blur: true,
        flare: true,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  register ? 'Join your workspace' : 'Your day, in focus.',
                  style: AppText.pageTitle.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  register
                      ? 'Create an account for administrator approval.'
                      : 'Meetings, people and progress. Together in one workspace.',
                  style: AppText.helper.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (register) ...registerFields() else ...[
                  input(
                    'email',
                    'Email',
                    required: true,
                    icon: Icons.alternate_email_rounded,
                    hint: 'you@company.com',
                  ),
                  input(
                    'password',
                    'Password',
                    required: true,
                    password: true,
                    icon: Icons.lock_outline_rounded,
                    hint: 'Your password',
                  ),
                ],
                if (error != null) ...[
                  InlineBanner(message: error!),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                AppButton(
                  label: busy
                      ? 'Please wait'
                      : register
                      ? 'Submit Registration'
                      : 'Sign In to Workspace',
                  trailingIcon: busy ? null : Icons.arrow_forward_rounded,
                  busy: busy,
                  expand: true,
                  size: ButtonSize.lg,
                  haptic: HapticKind.medium,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              register ? 'Already registered?' : 'New to your team workspace?',
              style: AppText.helper,
            ),
          ),
          TextButton(
            onPressed: busy ? null : toggleMode,
            child: Text(register ? 'Sign in' : 'Request Staff Access'),
          ),
        ],
      ),
    ],
  );

  List<Widget> registerFields() => [
    SegmentedTabs<bool>(
      compact: true,
      selected: company,
      onChanged: busy ? (_) {} : (v) => setState(() => company = v),
      segments: const [
        Segment(false, 'Join Existing Team', icon: Icons.groups_2_outlined),
        Segment(true, 'New Company (CEO)', icon: Icons.apartment_rounded),
      ],
    ),
    const SizedBox(height: 14),
    InlineBanner(
      kind: company ? BannerKind.warning : BannerKind.info,
      message: company
          ? 'Your company request goes to the Platform Developer. Once approved, your workspace and CEO access are activated together.'
          : 'Your request goes to your company Super Admin for review before you can sign in.',
    ),
    const SizedBox(height: 18),
    if (company)
      input(
        'company_name',
        'Company name',
        required: true,
        highlighted: true,
        icon: Icons.apartment_rounded,
      )
    else ...[
      AppDropdown<int>(
        label: 'Company',
        required: true,
        value: companyId,
        items: companies
            .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
            .toList(),
        validator: (v) => v == null ? 'Choose a company' : null,
        onChanged: (v) => setState(() {
          companyId = v;
          departmentId = null;
        }),
      ),
      AppDropdown<int>(
        key: ValueKey(companyId),
        label: 'Department (optional)',
        value: departmentId,
        items: departments
            .where((d) => d.companyId == companyId)
            .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
            .toList(),
        onChanged: (v) => setState(() => departmentId = v),
      ),
    ],
    input('name', 'Full name', required: true, icon: Icons.person_outline_rounded),
    input(
      'email',
      'Email',
      required: true,
      icon: Icons.alternate_email_rounded,
    ),
    input('title', 'Job title', icon: Icons.work_outline_rounded),
    input('phone', 'Phone', icon: Icons.phone_outlined),
    input(
      'password',
      'Password',
      required: true,
      password: true,
      icon: Icons.lock_outline_rounded,
    ),
    input(
      'password_confirmation',
      'Confirm password',
      required: true,
      password: true,
      icon: Icons.lock_outline_rounded,
    ),
    input(
      'registration_notes',
      'Note for the reviewer',
      lines: 3,
      hint: 'Anything that helps your administrator approve you',
    ),
  ];

  Widget statusGate() {
    final pending = accountStatus == 'pending';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        brandHeader(),
        const SizedBox(height: 32),
        GlassCard(
          tone: GlassTone.panel,
          blur: true,
          accentEdge: pending,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              IconTile(
                icon: pending
                    ? Icons.hourglass_top_rounded
                    : Icons.lock_outline_rounded,
                tint: pending ? Tint.warning : Tint.danger,
                size: 64,
                iconSize: 30,
                radius: AppRadii.innerAll,
              ),
              const SizedBox(height: 18),
              Text(
                'Account ${label(accountStatus!)}',
                style: AppText.pageTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              StatusPill(
                text: pending ? 'Pending Review' : titleCase(accountStatus!),
                tint: pending ? Tint.warning : Tint.danger,
                size: PillSize.md,
                dot: true,
              ),
              const SizedBox(height: 16),
              if (!pending && error != null)
                InlineBanner(title: 'Reason', message: error!)
              else
                Text(
                  error ??
                      'Your registration is with the administrator for review. You can sign in once it is approved.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Back to sign in',
                icon: Icons.arrow_back_rounded,
                variant: ButtonVariant.glass,
                expand: true,
                onPressed: () => setState(() {
                  accountStatus = null;
                  register = false;
                  error = null;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
