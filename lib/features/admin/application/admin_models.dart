import 'package:equatable/equatable.dart';

/// Platform roles an admin may grant or revoke on an account.
/// Mirrors the server's `ROLES` list.
const List<String> adminRoles = <String>[
  'WORKER',
  'EMPLOYER',
  'MODERATOR',
  'BILLING_ADMIN',
  'ADMIN',
];

/// Role filter chips offered in the console toolbar.
const List<String> adminRoleFilters = <String>[
  'ALL',
  ...adminRoles,
];

String roleFilterLabel(String role) => switch (role) {
  'ALL' => 'All',
  'WORKER' => 'Workers',
  'EMPLOYER' => 'Employers',
  'MODERATOR' => 'Moderators',
  'BILLING_ADMIN' => 'Billing admins',
  'ADMIN' => 'Admins',
  _ => role,
};

String personStatusLabel(String status) => switch (status) {
  'ACTIVE' => 'Active',
  'SUSPENDED' => 'Suspended',
  'DELETED' => 'Deleted',
  _ => status,
};

String identityStatusLabel(String status) => switch (status) {
  'NOT_STARTED' => 'Not started',
  'PENDING' => 'Pending',
  'NEEDS_ACTION' => 'Needs action',
  'VERIFIED' => 'Verified',
  'REJECTED' => 'Rejected',
  _ => status,
};

/// The worker sheet that admins can configure (and auto-create) for anyone.
class AdminWorkerProfile extends Equatable {
  const AdminWorkerProfile({
    this.publicName,
    this.baseArea,
    this.minRateNpr,
    this.rateNegotiable,
    this.availability,
    this.tagline,
    this.bio,
    this.verificationStatus,
  });

  factory AdminWorkerProfile.fromJson(Map<String, dynamic> json) =>
      AdminWorkerProfile(
        publicName: json['publicName'] as String?,
        baseArea: json['baseArea'] as String?,
        minRateNpr: (json['minRateNpr'] as num?)?.toInt(),
        rateNegotiable: json['rateNegotiable'] as bool?,
        availability: json['availability'] as String?,
        tagline: json['tagline'] as String?,
        bio: json['bio'] as String?,
        verificationStatus: json['verificationStatus'] as String?,
      );

  final String? publicName;
  final String? baseArea;
  final int? minRateNpr;
  final bool? rateNegotiable;
  final String? availability;
  final String? tagline;
  final String? bio;
  final String? verificationStatus;

  @override
  List<Object?> get props => [
    publicName,
    baseArea,
    minRateNpr,
    rateNegotiable,
    availability,
    tagline,
    bio,
    verificationStatus,
  ];
}

/// The employer (hirer) sheet that admins can configure and auto-create.
class AdminEmployerProfile extends Equatable {
  const AdminEmployerProfile({
    this.displayName,
    this.organization,
    this.trustStatus,
    this.profilePictureUrl,
    this.bio,
    this.tagline,
    this.baseArea,
    this.contactPhone,
    this.websiteUrl,
    this.categories = const [],
    this.languages = const [],
    this.portfolioUrls = const [],
  });

  factory AdminEmployerProfile.fromJson(Map<String, dynamic> json) =>
      AdminEmployerProfile(
        displayName: json['displayName'] as String?,
        organization: json['organization'] as String?,
        trustStatus: json['trustStatus'] as String?,
        profilePictureUrl: json['profilePictureUrl'] as String?,
        bio: json['bio'] as String?,
        tagline: json['tagline'] as String?,
        baseArea: json['baseArea'] as String?,
        contactPhone: json['contactPhone'] as String?,
        websiteUrl: json['websiteUrl'] as String?,
        categories: (json['categories'] as List<Object?>?)?.whereType<String>().toList(growable: false) ?? const [],
        languages: (json['languages'] as List<Object?>?)?.whereType<String>().toList(growable: false) ?? const [],
        portfolioUrls: (json['portfolioUrls'] as List<Object?>?)?.whereType<String>().toList(growable: false) ?? const [],
      );

  final String? displayName;
  final String? organization;
  final String? trustStatus;
  final String? profilePictureUrl;
  final String? bio;
  final String? tagline;
  final String? baseArea;
  final String? contactPhone;
  final String? websiteUrl;
  final List<String> categories;
  final List<String> languages;
  final List<String> portfolioUrls;

  @override
  List<Object?> get props => [
    displayName,
    organization,
    trustStatus,
    profilePictureUrl,
    bio,
    tagline,
    baseArea,
    contactPhone,
    websiteUrl,
    categories,
    languages,
    portfolioUrls,
  ];
}

/// One account row in the admin console, as returned by
/// `GET /v1/admin/people`.
class AdminPerson extends Equatable {
  const AdminPerson({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.status,
    required this.identityStatus,
    required this.onboardingComplete,
    required this.roles,
    required this.createdAt,
    required this.workerProfile,
    required this.employerProfile,
  });

  factory AdminPerson.fromJson(Map<String, dynamic> json) {
    final worker = json['workerProfile'];
    final employer = json['employerProfile'];
    final created = json['createdAt'];
    return AdminPerson(
      id: json['id'] as String,
      email: (json['email'] ?? '') as String,
      fullName: (json['fullName'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      status: (json['status'] ?? 'ACTIVE') as String,
      identityStatus: (json['identityStatus'] ?? 'NOT_STARTED') as String,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      roles:
          ((json['roles'] as List<Object?>?) ?? const [])
              .whereType<String>()
              .toList(growable: false),
      createdAt: created is String ? created : '',
      workerProfile: worker is Map<String, dynamic>
          ? AdminWorkerProfile.fromJson(worker)
          : null,
      employerProfile: employer is Map<String, dynamic>
          ? AdminEmployerProfile.fromJson(employer)
          : null,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String status;
  final String identityStatus;
  final bool onboardingComplete;
  final List<String> roles;
  final String createdAt;
  final AdminWorkerProfile? workerProfile;
  final AdminEmployerProfile? employerProfile;

  bool get isWorker => roles.contains('WORKER');
  bool get isEmployer => roles.contains('EMPLOYER');
  bool get isStaff =>
      roles.contains('ADMIN') ||
      roles.contains('MODERATOR') ||
      roles.contains('BILLING_ADMIN');

  String get roleLabel {
    if (roles.contains('ADMIN')) return 'Admin';
    if (roles.contains('BILLING_ADMIN')) return 'Billing admin';
    if (roles.contains('MODERATOR')) return 'Moderator';
    if (roles.contains('EMPLOYER')) return 'Employer';
    if (roles.contains('WORKER')) return 'Worker';
    return 'Member';
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    phone,
    status,
    identityStatus,
    onboardingComplete,
    roles,
    createdAt,
    workerProfile,
    employerProfile,
  ];
}
