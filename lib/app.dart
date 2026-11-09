import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kalla_lai/core/config/app_settings.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/localization/locale_cubit.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/presentation/auth_gate.dart';

class KallaLaiApp extends StatelessWidget {
  const KallaLaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    return BlocProvider(
      create: (_) => LocaleCubit()..select(Locale(settings.languageCode)),
      child: BlocBuilder<LocaleCubit, Locale>(
        builder:
            (context, locale) => MaterialApp(
              title: 'कल्ला-लाई',
              debugShowCheckedModeBanner: false,
              theme: KallaLaiTheme.light(),
              darkTheme: KallaLaiTheme.dark(),
              themeMode: settings.themeMode,
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('ne')],
              localizationsDelegates: const [
                AppStringsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AuthGate(),
            ),
      ),
    );
  }
}
