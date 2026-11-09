import 'package:equatable/equatable.dart';

enum AuthStatus { signedOut, signedIn }

class SessionUser extends Equatable {
  const SessionUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    this.isDemoSession = false,
    this.onboardingComplete = false,
    this.identityStatus = 'NOT_STARTED',
  });

  final String id;
  final String email;
  final String fullName;
  final List<String> roles;

  /// True when the session was created by the offline demo gateway instead of
  /// the live API. UI must label it so nobody believes a server login happened.
  final bool isDemoSession;
  final bool onboardingComplete;
  final String identityStatus;

  SessionUser copyWith({
    String? fullName,
    bool? onboardingComplete,
    String? identityStatus,
  }) => SessionUser(
    id: id,
    email: email,
    fullName: fullName ?? this.fullName,
    roles: roles,
    isDemoSession: isDemoSession,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    identityStatus: identityStatus ?? this.identityStatus,
  );

  bool get isEmployer => roles.contains('EMPLOYER');
  bool get isWorker => roles.contains('WORKER');

  /// Platform staff who may open the admin console.
  bool get isStaff =>
      roles.contains('ADMIN') ||
      roles.contains('MODERATOR') ||
      roles.contains('BILLING_ADMIN');

  String get roleLabel {
    if (roles.contains('BILLING_ADMIN')) return 'Billing admin';
    if (roles.contains('MODERATOR')) return 'Moderator';
    if (roles.contains('ADMIN')) return 'Admin';
    if (roles.contains('EMPLOYER')) return 'Employer';
    if (roles.contains('WORKER')) return 'Worker';
    return 'Member';
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    roles,
    isDemoSession,
    onboardingComplete,
    identityStatus,
  ];
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.user,
    this.busy = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final SessionUser? user;

  /// True while a sign-in / registration request is in flight.
  final bool busy;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    SessionUser? user,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, busy, errorMessage];
}
