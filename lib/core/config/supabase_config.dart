/// Client-safe Supabase settings, read at runtime from `GET /v1/app/config`.
///
/// The publishable key (`sb_publishable_...`) is designed to be public and is
/// delivered by our own API rather than baked into the app bundle, so the
/// project URL can change without rebuilding the client. Supabase keys are
/// sent on the `apikey` header, not as a bearer token.
class SupabaseSettings {
  const SupabaseSettings({
    required this.url,
    required this.publishableKey,
    required this.projectRef,
    required this.backend,
    required this.dataApiConfigured,
    required this.databaseConfigured,
    this.configurationWarning,
  });

  factory SupabaseSettings.fromAppConfig(Map<String, dynamic> json) {
    final nested = json['supabase'];
    final config = nested is Map<String, dynamic> ? nested : json;
    return SupabaseSettings(
      url: (config['url'] ?? json['supabaseUrl']) as String?,
      publishableKey:
          (config['publishableKey'] ?? json['supabasePublishableKey']) as String?,
      projectRef: config['projectRef'] as String?,
      backend: (json['backend'] as String?) ?? 'PGLOCAL',
      dataApiConfigured: config['dataApiConfigured'] as bool? ?? false,
      databaseConfigured: config['databaseConfigured'] as bool? ?? false,
      configurationWarning: config['configurationWarning'] as String?,
    );
  }

  static const empty = SupabaseSettings(
    url: null,
    publishableKey: null,
    projectRef: null,
    backend: 'PGLOCAL',
    dataApiConfigured: false,
    databaseConfigured: false,
  );

  final String? url;
  final String? publishableKey;
  final String? projectRef;
  final String backend;
  final bool dataApiConfigured;
  final bool databaseConfigured;
  final String? configurationWarning;

  bool get usesSupabase => backend == 'SUPABASE';

  String get backendLabel => switch (backend) {
    'SUPABASE' => 'Supabase',
    'POSTGRES' => 'PostgreSQL',
    _ => 'Local engine',
  };

  /// Headers for a direct Supabase Data API (PostgREST) request.
  Map<String, String> get restHeaders => {
    'accept': 'application/json',
    'content-type': 'application/json',
    if (publishableKey != null) 'apikey': publishableKey!,
  };

  Uri? restUri(String path) {
    final base = url;
    if (base == null) return null;
    return Uri.parse('$base/rest/v1/$path');
  }
}
