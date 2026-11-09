import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/app.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/config/app_settings.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/auth/data/firebase_google_identity_provider.dart';
import 'package:kalla_lai/features/discovery/application/vacancy_discovery_cubit.dart';
import 'package:kalla_lai/features/hiring/application/hiring_requisition_cubit.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/shared/data/api_marketplace_repository.dart';
import 'package:kalla_lai/features/shared/data/demo_marketplace_repository.dart';
import 'package:kalla_lai/features/shared/data/marketplace_repository.dart';
import 'package:kalla_lai/features/shifts/application/shift_escrow_cubit.dart';

/// One web build works both locally and when hosted.
///
/// Both environments serve the API on the same origin as the web bundle:
/// the deployed site does it in one Node process, and `serve-web.js` proxies
/// `/v1` to the API on port 8090 for the local dev server on port 7358. So the
/// default is always same-origin `/v1`, which keeps local and hosted builds
/// behaving the same. An explicit non-empty dart-define always wins.
String resolveApiBaseUrl() {
  const configured = AppConfig.apiBaseUrl;
  if (configured.isNotEmpty) return configured;
  if (!kIsWeb) return 'http://127.0.0.1:8090';
  // Same origin everywhere: /v1 is proxied locally and served directly when
  // deployed. Nothing here needs to know the host name.
  return '';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A user-supplied API URL (from Settings) overrides the build/runtime
  // default, so no rebuild is needed to point the app at another server.
  final apiClient = ApiClient(
    baseUrl: AppSettingsCubit.savedApiUrlOverride ?? resolveApiBaseUrl(),
  );
  // Cubits start loading data on the very first frame, before the silent
  // session refresh finishes. Seed the cached access token so those requests
  // are authenticated immediately (the refresh rotates it a moment later).
  apiClient.setAccessToken(SessionStore.accessToken);
  final demoRepository = DemoMarketplaceRepository();
  final MarketplaceRepository repository =
      AppConfig.liveApiEnabled
          ? ApiMarketplaceRepository(apiClient)
          : demoRepository;
  final googleIdentityProvider =
      AppConfig.liveApiEnabled
          ? DeferredGoogleIdentityProvider(
            FirebaseGoogleIdentityProvider.initialize()
                .timeout(const Duration(seconds: 20), onTimeout: () => null)
                .catchError((Object _) => null),
          )
          : null;
  final authGateway =
      AppConfig.liveApiEnabled
          ? ApiAuthGateway(
            apiClient,
            googleIdentityProvider: googleIdentityProvider,
          )
          : OfflineAuthGateway();
  final authCubit = AuthCubit(authGateway);

  runApp(
    RepositoryProvider.value(
      value: apiClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AppSettingsCubit()),
          BlocProvider(create: (_) => ModeSwitcherCubit()),
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider(create: (_) => EntryJourneyCubit(apiClient)),
          BlocProvider(
            create: (_) => VacancyDiscoveryCubit(repository)..load(),
          ),
          BlocProvider(create: (_) => HiringRequisitionCubit(apiClient)),
          BlocProvider(
            create:
                (_) => ShiftEscrowCubit(demoRepository.initialLedgerEntry()),
          ),
        ],
        child: const KallaLaiApp(),
      ),
    ),
  );

  // Restore AFTER the first frame: a slow/unreachable API must never be able
  // to keep the app on a blank screen. Both Google and email sessions use the
  // same persisted refresh token.
  unawaited(authCubit.restoreSession());
}
