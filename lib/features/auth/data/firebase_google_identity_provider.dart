import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/config/firebase_app_options.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';

/// Lets the app render its intro immediately while Firebase sets up in the
/// background. A slow or blocked Firebase network must never trap startup.
class DeferredGoogleIdentityProvider implements GoogleIdentityProvider {
  DeferredGoogleIdentityProvider(Future<GoogleIdentityProvider?> initialization)
    : _initialization = initialization;

  final Future<GoogleIdentityProvider?> _initialization;

  @override
  Future<GoogleIdentityToken?> signIn() async {
    final provider = await _initialization;
    if (provider == null) {
      throw const ApiException(
        'Google sign-in is unavailable right now. Please use email and password.',
        code: 'GOOGLE_SIGN_IN_UNAVAILABLE',
      );
    }
    return provider.signIn();
  }

  @override
  Future<void> signOut() async {
    final provider = await _initialization;
    await provider?.signOut();
  }
}

class FirebaseGoogleIdentityProvider implements GoogleIdentityProvider {
  FirebaseGoogleIdentityProvider._({
    required FirebaseAuth auth,
    required GoogleSignIn googleSignIn,
  }) : _auth = auth,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  static Future<FirebaseGoogleIdentityProvider?> initialize() async {
    final options = FirebaseAppOptions.forCurrentPlatform();
    if (options == null) return null;
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    if (!FirebaseAppOptions.googleNativeClientConfigured) {
      throw StateError(
        'Firebase is configured but the native Google OAuth client IDs are '
        'missing.',
      );
    }

    await Firebase.initializeApp(options: options);
    final googleSignIn = GoogleSignIn.instance;
    if (!kIsWeb) {
      await googleSignIn.initialize(
        clientId:
            defaultTargetPlatform == TargetPlatform.iOS
                ? AppConfig.firebaseIosClientId
                : AppConfig.firebaseAndroidClientId.isEmpty
                ? null
                : AppConfig.firebaseAndroidClientId,
        serverClientId: AppConfig.googleWebClientId,
      );
    }
    return FirebaseGoogleIdentityProvider._(
      auth: FirebaseAuth.instance,
      googleSignIn: googleSignIn,
    );
  }

  @override
  Future<GoogleIdentityToken?> signIn() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final account = await _googleSignIn.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-google-id-token',
            message: 'Google did not return an ID token. Check OAuth setup.',
          );
        }
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      final user = credential.user;
      final idToken = await user?.getIdToken();
      if (user == null || idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-firebase-id-token',
          message: 'Firebase did not return an authenticated user token.',
        );
      }
      return GoogleIdentityToken(idToken: idToken);
    } on FirebaseAuthException catch (error) {
      if (_cancelCodes.contains(error.code)) {
        throw const ApiException(
          'Google sign-in was cancelled.',
          code: googleSignInCancelledCode,
        );
      }
      throw ApiException(
        _errorMessage(error.code),
        code: error.code,
        statusCode:
            error.code == 'account-exists-with-different-credential'
                ? 409
                : null,
      );
    } on GoogleSignInException catch (error) {
      final cancelled = error.code == GoogleSignInExceptionCode.canceled;
      throw ApiException(
        cancelled
            ? 'Google sign-in was cancelled.'
            : 'Google sign-in failed. Check the Firebase OAuth configuration.',
        code:
            cancelled
                ? googleSignInCancelledCode
                : 'GOOGLE_SIGN_IN_${error.code.name.toUpperCase()}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await _googleSignIn.signOut();
  }

  /// Firebase codes for "the person closed or abandoned the Google window".
  static const Set<String> _cancelCodes = <String>{
    'popup-closed-by-user',
    'cancelled-popup-request',
    'user-cancelled',
    'web-context-cancelled',
    'web-context-canceled',
  };

  String _errorMessage(String code) => switch (code) {
    'account-exists-with-different-credential' =>
      'This email already uses another sign-in method. Sign in with that method first.',
    'network-request-failed' =>
      'Could not reach Firebase. Check your connection and try again.',
    'popup-blocked' =>
      'Your browser blocked the Google sign-in window. Allow pop-ups for this '
      'site and try again.',
    'unauthorized-domain' =>
      'This website domain is not authorised for Google sign-in yet. Add the '
      'site domain under Firebase Authentication > Settings > Authorized '
      'domains, then reload the app.',
    'missing-google-id-token' =>
      'Google did not return an ID token. Check the OAuth configuration.',
    'missing-firebase-id-token' =>
      'Firebase did not return an authenticated user token.',
    _ => 'Google sign-in failed. Please try again.',
  };
}
