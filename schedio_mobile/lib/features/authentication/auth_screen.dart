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

  Widget input(
    String key,
    String title, {
    bool required = false,
    bool password = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: field(key),
      obscureText: password && obscure,
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      autofillHints: key == 'email'
          ? [AutofillHints.email]
          : password
          ? [AutofillHints.password]
          : null,
      decoration: InputDecoration(
        labelText: title,
        suffixIcon: password
            ? IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
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
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (accountStatus != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountStatus == 'pending'
                          ? Icons.hourglass_top
                          : Icons.lock_outline,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account ${label(accountStatus!)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error ?? 'Your registration is with the administrator for review.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => setState(() {
                        accountStatus = null;
                        register = false;
                        error = null;
                      }),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/schedio-logo.jpg',
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Schedio',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    Text(
                      register ? 'Join your workspace' : 'Your day, in focus.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      register
                          ? 'Create an account for administrator approval.'
                          : 'Meetings, people and progress.\nTogether in one workspace.',
                    ),
                    const SizedBox(height: 32),
                    if (register) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Register a new company'),
                        value: company,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => company = v),
                      ),
                      input('name', 'Full name', required: true),
                      if (company)
                        input('company_name', 'Company name', required: true)
                      else ...[
                        DropdownButtonFormField<int>(
                          initialValue: companyId,
                          decoration: const InputDecoration(
                            labelText: 'Company',
                          ),
                          items: companies
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          validator: (v) =>
                              v == null ? 'Choose a company' : null,
                          onChanged: (v) => setState(() {
                            companyId = v;
                            departmentId = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(companyId),
                          initialValue: departmentId,
                          decoration: const InputDecoration(
                            labelText: 'Department (optional)',
                          ),
                          items: departments
                              .where((d) => d.companyId == companyId)
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => departmentId = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                      input('title', 'Job title'),
                      input('phone', 'Phone'),
                    ],
                    input('email', 'Email', required: true),
                    input(
                      'password',
                      'Password',
                      required: true,
                      password: true,
                    ),
                    if (register) ...[
                      input(
                        'password_confirmation',
                        'Confirm password',
                        required: true,
                        password: true,
                      ),
                      input('registration_notes', 'Registration notes'),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy
                            ? 'Please wait…'
                            : register
                            ? 'Submit registration'
                            : 'Sign in',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                register = !register;
                                error = null;
                              });
                              if (register) options();
                            },
                      child: Text(
                        register
                            ? 'Already registered? Sign in'
                            : 'Request an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
