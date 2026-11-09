import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/app_settings.dart';
import 'package:kalla_lai/core/localization/locale_cubit.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';

void openSettings(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}

/// Small gear used on the pre-login screens so settings are always reachable.
class SettingsLauncher extends StatelessWidget {
  const SettingsLauncher({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    icon: const Icon(Icons.settings_outlined, size: 20),
    onPressed: () => openSettings(context),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Section(
            title: 'Appearance & language',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Theme',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) => context
                        .read<AppSettingsCubit>()
                        .setThemeMode(value.first),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Language',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'ne', label: Text('नेपाली')),
                  ],
                  selected: {settings.languageCode},
                  onSelectionChanged: (value) {
                    final code = value.first;
                    context.read<AppSettingsCubit>().setLanguage(code);
                    context.read<LocaleCubit>().select(Locale(code));
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Stored on this device'),
                value: settings.notificationsEnabled,
                onChanged: (value) =>
                    context.read<AppSettingsCubit>().setNotifications(value),
              ),
            ],
          ),
          _Section(
            title: 'Account & saved sign-in',
            children: [
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, auth) {
                  final user = auth.user;
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          user?.fullName ?? 'Not signed in',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          user?.email ??
                              SessionStore.rememberedEmail ??
                              'Sign in with email or Google — the session is remembered on this device.',
                        ),
                      ),
                      if (user != null)
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign out'),
                          subtitle: const Text(
                            'Clears the saved session on this device',
                          ),
                          onTap: () => context.read<AuthCubit>().signOut(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'About कल्ला-लाई',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('App Name'),
                subtitle: Text('कल्ला-लाई  (Kalla-Lai)'),
              ),
              const ListTile(
                leading: Icon(Icons.business_outlined),
                title: Text('Developer'),
                subtitle: Text('Innovator123'),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Copyright'),
                subtitle: Text(
                  '© ${DateTime.now().year} Kalla-Lai. All rights reserved.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              const ListTile(
                leading: Icon(Icons.description_outlined),
                title: Text('License'),
                subtitle: Text('All rights reserved. Unauthorised use prohibited.'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(
                  'कल्ला-लाई is a labour marketplace connecting workers and employers '
                  'across Nepal. All trademarks and intellectual property remain '
                  'the exclusive property of their respective owners.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}
