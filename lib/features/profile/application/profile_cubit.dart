import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/networking/api_client.dart';

class WorkerProfile extends Equatable {
  const WorkerProfile({
    this.publicName = '',
    this.baseArea = '',
    this.latitude,
    this.longitude,
    this.minRateNpr = 0,
    this.rateNegotiable = true,
    this.availability = '',
    this.bio = '',
    this.verificationStatus = 'PENDING',
    this.tagline = '',
    this.languages = const [],
    this.categories = const [],
    this.promoVideoUrl = '',
    this.cvUrl = '',
    this.portfolioUrls = const [],
  });

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
    publicName: json['public_name']?.toString() ?? '',
    baseArea: json['base_area']?.toString() ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    minRateNpr: int.tryParse('${json['min_rate_npr']}') ?? 0,
    rateNegotiable: json['rate_negotiable'] != false,
    availability: json['availability']?.toString() ?? '',
    bio: json['bio']?.toString() ?? '',
    verificationStatus: json['verification_status']?.toString() ?? 'PENDING',
    tagline: json['tagline']?.toString() ?? '',
    languages: _stringList(json['languages']),
    categories: _stringList(json['categories']),
    promoVideoUrl: json['promo_video_url']?.toString() ?? '',
    cvUrl: json['cv_url']?.toString() ?? '',
    portfolioUrls: _stringList(json['portfolio_urls']),
  );

  final String publicName;
  final String baseArea;
  final double? latitude;
  final double? longitude;
  final int minRateNpr;
  final bool rateNegotiable;
  final String availability;
  final String bio;
  final String verificationStatus;
  final String tagline;
  final List<String> languages;
  final List<String> categories;
  final String promoVideoUrl;
  final String cvUrl;
  final List<String> portfolioUrls;

  @override
  List<Object?> get props => [
    publicName,
    baseArea,
    latitude,
    longitude,
    minRateNpr,
    rateNegotiable,
    availability,
    bio,
    verificationStatus,
    tagline,
    languages,
    categories,
    promoVideoUrl,
    cvUrl,
    portfolioUrls,
  ];
}

List<String> _stringList(Object? value) =>
    value is List
        ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(growable: false)
        : const [];

class EmployerProfile extends Equatable {
  const EmployerProfile({
    this.displayName = '',
    this.organization = '',
    this.trustStatus = 'UNVERIFIED',
    this.profilePictureUrl = '',
    this.bio = '',
    this.tagline = '',
    this.baseArea = '',
    this.latitude,
    this.longitude,
    this.contactPhone = '',
    this.websiteUrl = '',
    this.categories = const [],
    this.languages = const [],
    this.portfolioUrls = const [],
  });

  factory EmployerProfile.fromJson(Map<String, dynamic> json) =>
      EmployerProfile(
        displayName: json['display_name']?.toString() ?? '',
        organization: json['organization']?.toString() ?? '',
        trustStatus: json['trust_status']?.toString() ?? 'UNVERIFIED',
        profilePictureUrl: json['profile_picture_url']?.toString() ?? '',
        bio: json['bio']?.toString() ?? '',
        tagline: json['tagline']?.toString() ?? '',
        baseArea: json['base_area']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        contactPhone: json['contact_phone']?.toString() ?? '',
        websiteUrl: json['website_url']?.toString() ?? '',
        categories: _stringList(json['categories']),
        languages: _stringList(json['languages']),
        portfolioUrls: _stringList(json['portfolio_urls']),
      );

  final String displayName;
  final String organization;
  final String trustStatus;
  final String profilePictureUrl;
  final String bio;
  final String tagline;
  final String baseArea;
  final double? latitude;
  final double? longitude;
  final String contactPhone;
  final String websiteUrl;
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
    latitude,
    longitude,
    contactPhone,
    websiteUrl,
    categories,
    languages,
    portfolioUrls,
  ];
}

class WorkerSkill extends Equatable {
  const WorkerSkill({
    required this.slug,
    required this.name,
    this.yearsExperience = 0,
  });

  factory WorkerSkill.fromJson(Map<String, dynamic> json) => WorkerSkill(
    slug: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    yearsExperience: num.tryParse('${json['years_experience']}')?.toInt() ?? 0,
  );

  final String slug;
  final String name;
  final int yearsExperience;

  @override
  List<Object?> get props => [slug, name, yearsExperience];
}

class ProfileState extends Equatable {
  const ProfileState({
    this.loading = false,
    this.loaded = false,
    this.saving = false,
    this.worker,
    this.employer,
    this.skills = const [],
    this.errorMessage,
    this.savedMessage,
  });

  final bool loading;
  final bool loaded;
  final bool saving;
  final WorkerProfile? worker;
  final EmployerProfile? employer;
  final List<WorkerSkill> skills;
  final String? errorMessage;
  final String? savedMessage;

  ProfileState copyWith({
    bool? loading,
    bool? loaded,
    bool? saving,
    WorkerProfile? worker,
    EmployerProfile? employer,
    List<WorkerSkill>? skills,
    String? errorMessage,
    bool clearError = false,
    String? savedMessage,
    bool clearSaved = false,
  }) => ProfileState(
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    saving: saving ?? this.saving,
    worker: worker ?? this.worker,
    employer: employer ?? this.employer,
    skills: skills ?? this.skills,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    savedMessage: clearSaved ? null : savedMessage ?? this.savedMessage,
  );

  @override
  List<Object?> get props => [
    loading,
    loaded,
    saving,
    worker,
    employer,
    skills,
    errorMessage,
    savedMessage,
  ];
}

/// Loads and saves the signed-in account's own profile. Workers and employers
/// can only edit the profile that matches their account role — the API
/// enforces the same rule.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._client) : super(const ProfileState());

  final ApiClient _client;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, clearSaved: true));
    try {
      final json = await _client.getJson('/v1/me');
      final workerJson = json['workerProfile'];
      final employerJson = json['employerProfile'];
      var skills = const <WorkerSkill>[];
      if (workerJson is Map<String, dynamic>) {
        final skillsJson = await _client.getJson(
          '/v1/workers/me/skills',
        );
        final items = skillsJson['items'];
        if (items is List) {
          skills = items
              .whereType<Map<String, dynamic>>()
              .map(WorkerSkill.fromJson)
              .toList(growable: false);
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          loaded: true,
          worker:
              workerJson is Map<String, dynamic>
                  ? WorkerProfile.fromJson(workerJson)
                  : null,
          employer:
              employerJson is Map<String, dynamic>
                  ? EmployerProfile.fromJson(employerJson)
                  : null,
          skills: skills,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Could not load your profile. Is the server running?',
        ),
      );
    }
  }

  Future<void> saveWorker(Map<String, dynamic> fields) async {
    await _save('/v1/workers/me', fields, (json) {
      final profile = json['workerProfile'];
      return state.copyWith(
        saving: false,
        worker:
            profile is Map<String, dynamic>
                ? WorkerProfile.fromJson(profile)
                : state.worker,
        savedMessage: 'Profile saved',
      );
    });
  }

  Future<void> saveEmployer(Map<String, dynamic> fields) async {
    await _save('/v1/employers/me', fields, (json) {
      final profile = json['employerProfile'];
      return state.copyWith(
        saving: false,
        employer:
            profile is Map<String, dynamic>
                ? EmployerProfile.fromJson(profile)
                : state.employer,
        savedMessage: 'Profile saved',
      );
    });
  }

  Future<void> addSkill(String name) async {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length < 2) {
      emit(state.copyWith(errorMessage: 'Enter a skill name to add.'));
      return;
    }
    emit(state.copyWith(saving: true, clearError: true, clearSaved: true));
    try {
      await _client.postJson(
        '/v1/workers/me/skills',
        body: {'slug': slug, 'name': name.trim()},
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          saving: false,
          skills: [
            ...state.skills.where((skill) => skill.slug != slug),
            WorkerSkill(slug: slug, name: name.trim()),
          ],
          savedMessage: 'Skill added',
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(saving: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(saving: false, errorMessage: 'Could not add the skill.'),
      );
    }
  }

  Future<void> removeSkill(String slug) async {
    emit(state.copyWith(saving: true, clearError: true, clearSaved: true));
    try {
      await _client.deleteJson('/v1/workers/me/skills/$slug');
      if (isClosed) return;
      emit(
        state.copyWith(
          saving: false,
          skills: state.skills.where((skill) => skill.slug != slug).toList(),
          savedMessage: 'Skill removed',
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(saving: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Could not remove the skill.',
        ),
      );
    }
  }

  Future<String?> uploadMedia({
    required String kind,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    emit(state.copyWith(saving: true, clearError: true, clearSaved: true));
    try {
      final json = await _client.uploadFile(
        kind: kind,
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );
      if (isClosed) return null;
      emit(state.copyWith(saving: false));
      return json['url']?.toString();
    } on ApiException catch (error) {
      if (isClosed) return null;
      emit(state.copyWith(saving: false, errorMessage: error.message));
      return null;
    } catch (_) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Could not upload the file. Please try again.',
        ),
      );
      return null;
    }
  }

  Future<void> _save(
    String path,
    Map<String, dynamic> fields,
    ProfileState Function(Map<String, dynamic> json) onSuccess,
  ) async {
    emit(state.copyWith(saving: true, clearError: true, clearSaved: true));
    try {
      final json = await _client.patchJson(path, body: fields);
      if (isClosed) return;
      emit(onSuccess(json));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(saving: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Could not save your profile. Please try again.',
        ),
      );
    }
  }
}
