import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/config/app_settings.dart';
import 'package:kalla_lai/core/localization/locale_cubit.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrl = TextEditingController();
  Map<String, dynamic> _config = const {};
  String? _configError;
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _apiUrl.text = context.read<ApiClient>().baseUrl;
    _loadConfig();
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final json = await context.read<ApiClient>().getJson('/v1/app/config');
      if (!mounted) return;
      setState(() {
        _config = json;
        _loadingConfig = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _configError = error.toString();
        _loadingConfig = false;
      });
    }
  }

  void _applyApiUrl() {
    final value = _apiUrl.text.trim();
    context.read<ApiClient>().updateBaseUrl(value);
    context.read<AppSettingsCubit>().setApiUrlOverride(value);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API address updated.')));
    _loadConfig();
  }

  void _resetApiUrl() {
    final override = AppSettingsCubit.savedApiUrlOverride;
    if (override == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already using the default API address.')),
      );
      return;
    }
    // Restoring the build default needs a reload to recompute the local/hosted
    // choice; clear the override and tell the user plainly.
    context.read<AppSettingsCubit>().setApiUrlOverride('');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Override cleared. Reload the page to use the default.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh server configuration',
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfig,
          ),
        ],
      ),
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
                onChanged: (value) => context
                    .read<AppSettingsCubit>()
                    .setNotifications(value),
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
                          onTap: () =>
                              context.read<AuthCubit>().signOut(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Connection',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _apiUrl,
                  decoration: const InputDecoration(
                    labelText: 'API server URL',
                    helperText:
                        'Leave empty to use this same website as the API.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: _applyApiUrl,
                      child: const Text('Apply'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _resetApiUrl,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              _ConfigTile('Current API', _apiUrl.text.isEmpty ? '(same origin)' : _apiUrl.text),
              _ConfigTile('This site', kIsWeb ? Uri.base.host : 'mobile/desktop'),
              const _ConfigTile('Live API', AppConfig.liveApiEnabled ? 'Enabled' : 'Offline demo'),
            ],
          ),
          _Section(
            title: 'Sign-in configuration',
            children: [
              _ConfigTile('Firebase project', AppConfig.firebaseProjectId.isEmpty ? 'Not set' : AppConfig.firebaseProjectId),
              const _ConfigTile('Auth domain', AppConfig.firebaseAuthDomain),
              _ConfigTile(
                'Google sign-in',
                context.read<AuthCubit>().googleSignInConfigured
                    ? 'Available in this build'
                    : 'Not available',
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'Google sign-in requires this website\'s domain in Firebase '
                  'Authentication > Settings > Authorized domains. '
                  'Add the host shown above, then reload — no redeploy needed.',
                ),
              ),
            ],
          ),
          _Section(
            title: 'Server configuration',
            children: [
              if (_loadingConfig)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_configError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not read /v1/app/config: $_configError'),
                )
              else if (_config.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No server settings returned.'),
                )
              else
                ..._config.entries
                    .where(
                      (entry) =>
                          entry.value == null ||
                          entry.value is String ||
                          entry.value is bool ||
                          entry.value is num,
                    )
                    .map(
                      (entry) => _ConfigTile(
                        _labelFor(entry.key),
                        '${entry.value ?? '—'}',
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

String _labelFor(String key) {
  final spaced = key.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match[1]} ${match[2]}',
  );
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
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

class _ConfigTile extends StatelessWidget {
  const _ConfigTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    subtitle: SelectableText(
      value,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
