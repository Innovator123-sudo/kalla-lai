import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const _values = <String, Map<String, String>>{
    'en': {
      'vacancy': 'Vacancy',
      'hiring': 'Hiring',
      'discover': 'Discover work',
      'post_work': 'Post work',
      'shift': 'Shift & pay',
      'profile': 'Profile',
      'demo_banner': 'DEMO · Sample data only · No action reaches a server',
      'live_banner':
          'DEMO UI · Listings come from the live API · Shift and payment actions are sample-only',
      'nearby': 'Work near you',
      'distance': 'Search radius',
      'verified_employer': 'Verified employer',
      'pending': 'Pending review',
      'on_my_way': 'On my way',
      'check_in': 'Check in',
      'support': 'Contact support',
      'language': 'Language',
      'english': 'English',
      'nepali': 'नेपाली',
      'profile_title': 'Worker profile',
      'shift_title': 'Shift & payment status',
      'hiring_title': 'Post work',
      'hiring_intro':
          'Four quick questions. You can change anything before you send it.',
      'hiring_progress': 'Question {step} of 4 · Takes about a minute',
      'login_subtitle': 'Sign in to post work or manage your shifts',
      'signin': 'Sign in',
      'create_account': 'New account',
      'account_type': 'Account type',
      'role_worker': 'I want to work',
      'role_employer': 'I need work done',
      'password': 'Password',
      'signin_btn': 'Sign in',
      'create_btn': 'Create account',
      'demo_accounts': 'Demo accounts',
      'account_menu': 'Account menu',
      'demo_session': 'demo session',
      'sign_out': 'Sign out',
      'google_account_type': 'New Google account type',
      'google_sign_in': 'Continue with Google',
      'firebase_not_configured':
          'Google sign-in is unavailable until Firebase is configured.',
      'offline_login_note':
          'Offline demo mode is enabled. Sign-in creates a local demo session only — it is not a server login.',
    },
    'ne': {
      'vacancy': 'काम खोज्ने',
      'hiring': 'काम दिने',
      'discover': 'काम खोज्नुहोस्',
      'post_work': 'काम राख्नुहोस्',
      'shift': 'सिफ्ट र भुक्तानी',
      'profile': 'प्रोफाइल',
      'demo_banner': 'डेमो · नमुना डेटा · सर्भरमा कुनै कार्य पठाइँदैन',
      'live_banner':
          'डेमो UI · सूची सर्भरबाट आउँछ · सिफ्ट र भुक्तानीका कार्य नमुना हुन्',
      'nearby': 'नजिकको काम',
      'distance': 'खोज दायरा',
      'verified_employer': 'प्रमाणित रोजगारदाता',
      'pending': 'समीक्षामा',
      'on_my_way': 'म आउँदैछु',
      'check_in': 'हाजिर गर्नुहोस्',
      'support': 'सहयोगमा सम्पर्क',
      'language': 'भाषा',
      'english': 'English',
      'nepali': 'नेपाली',
      'profile_title': 'कामदार प्रोफाइल',
      'shift_title': 'सिफ्ट र भुक्तानी स्थिति',
      'hiring_title': 'काम पोस्ट गर्नुहोस्',
      'hiring_intro': 'चार छोटा प्रश्न। पठाउनु अघि सबै कुरा बदल्न सक्नुहुन्छ।',
      'hiring_progress': 'प्रश्न {step} / ४ · करिब एक मिनेट लाग्छ',
      'login_subtitle': 'काम राख्न वा सिफ्ट व्यवस्थापन गर्न साइन इन गर्नुहोस्',
      'signin': 'साइन इन',
      'create_account': 'नयाँ खाता',
      'account_type': 'खाताको प्रकार',
      'role_worker': 'म काम गर्न चाहन्छु',
      'role_employer': 'म काम गराउन चाहन्छु',
      'password': 'पासवर्ड',
      'signin_btn': 'साइन इन',
      'create_btn': 'खाता बनाउनुहोस्',
      'demo_accounts': 'डेमो खाताहरू',
      'account_menu': 'खाता मेनु',
      'demo_session': 'डेमो सेसन',
      'sign_out': 'साइन आउट',
      'google_account_type': 'नयाँ गुगल खाताको प्रकार',
      'google_sign_in': 'गुगलबाट जारी राख्नुहोस्',
      'firebase_not_configured':
          'Firebase कन्फिगर नभएसम्म गुगल साइन इन उपलब्ध हुँदैन।',
      'offline_login_note':
          'अफलाइन डेमो मोड सक्रिय छ। साइन इन लोकल डेमो सेसन मात्र बनाउँछ — सर्भर लगइन होइन।',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'ne'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings(locale));

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
