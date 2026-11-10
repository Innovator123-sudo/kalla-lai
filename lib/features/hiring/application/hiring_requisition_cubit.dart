import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/location/device_location.dart';
import 'package:kalla_lai/core/maps/map_link.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

enum HiringStep { work, schedule, budget, review }

class HiringWizardState extends Equatable {
  const HiringWizardState({
    this.step = HiringStep.work,
    this.role = 'Certified Electrician',
    this.category = 'Construction & Trades',
    this.area = 'Koteshwor, Kathmandu',
    this.details = '',
    this.companyInfo = '',
    this.shiftLabel = 'Tomorrow · 08:00–14:00',
    this.rateNpr = 1800,
    this.contactPhone = '',
    this.workingHours = '',
    this.employmentType = 'FULL_TIME',
    this.openings = 1,
    this.salaryIncrement = false,
    this.incrementNote = '',
    this.compensationType = 'DAILY',
    this.negotiable = true,
    this.googleMapsLink = '',
    this.latitude,
    this.longitude,
    this.locating = false,
    this.submitting = false,
    this.submitted = false,
    this.serverJobId,
    this.serverDraft = false,
    this.localPreview = false,
    this.notice,
    this.errorMessage,
  });

  final HiringStep step;
  final String role;
  final String category;
  final String area;
  final String details;
  final String companyInfo;
  final String shiftLabel;
  final int rateNpr;
  final String contactPhone;
  final String workingHours;
  final String employmentType;
  final int openings;
  final bool salaryIncrement;
  final String incrementNote;
  final String compensationType;
  final bool negotiable;
  final String googleMapsLink;
  final double? latitude;
  final double? longitude;
  final bool locating;
  final bool submitting;
  final bool submitted;
  final String? serverJobId;

  /// True when the API accepted the requisition as a DRAFT (not published).
  final bool serverDraft;
  final bool localPreview;
  final String? notice;
  final String? errorMessage;

  bool get hasTrueLocation => latitude != null && longitude != null;

  /// True when a non-empty link is not a Google Maps URL or a coordinate pin.
  /// The wizard uses this for inline validation instead of failing at submit.
  bool get hasInvalidMapsLink {
    final link = googleMapsLink.trim();
    return link.isNotEmpty && !MapLink.isValid(link);
  }

  String get composedDescription {
    final parts = <String>[];
    final trimmedDetails = details.trim();
    if (trimmedDetails.length >= 10) parts.add(trimmedDetails);
    final trimmedCompany = companyInfo.trim();
    if (trimmedCompany.isNotEmpty) parts.add('About us: $trimmedCompany');
    final trimmedMaps = googleMapsLink.trim();
    if (trimmedMaps.isNotEmpty) parts.add('Location link: $trimmedMaps');
    if (parts.isNotEmpty) return parts.join('\n\n');
    final base = '$role needed in $area. Shift window: $shiftLabel.';
    if (trimmedMaps.isNotEmpty) return '$base\n\nLocation link: $trimmedMaps';
    return base;
  }

  HiringWizardState copyWith({
    HiringStep? step,
    String? role,
    String? category,
    String? area,
    String? details,
    String? companyInfo,
    String? shiftLabel,
    int? rateNpr,
    String? contactPhone,
    String? workingHours,
    String? employmentType,
    int? openings,
    bool? salaryIncrement,
    String? incrementNote,
    String? compensationType,
    bool? negotiable,
    String? googleMapsLink,
    double? latitude,
    double? longitude,
    bool? locating,
    bool? submitting,
    bool? submitted,
    String? serverJobId,
    bool clearServerJobId = false,
    bool? serverDraft,
    bool? localPreview,
    String? notice,
    String? errorMessage,
    bool clearNotice = false,
    bool clearError = false,
  }) {
    return HiringWizardState(
      step: step ?? this.step,
      role: role ?? this.role,
      category: category ?? this.category,
      area: area ?? this.area,
      details: details ?? this.details,
      companyInfo: companyInfo ?? this.companyInfo,
      shiftLabel: shiftLabel ?? this.shiftLabel,
      rateNpr: rateNpr ?? this.rateNpr,
      contactPhone: contactPhone ?? this.contactPhone,
      workingHours: workingHours ?? this.workingHours,
      employmentType: employmentType ?? this.employmentType,
      openings: openings ?? this.openings,
      salaryIncrement: salaryIncrement ?? this.salaryIncrement,
      incrementNote: incrementNote ?? this.incrementNote,
      compensationType: compensationType ?? this.compensationType,
      negotiable: negotiable ?? this.negotiable,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locating: locating ?? this.locating,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      serverJobId: clearServerJobId ? null : serverJobId ?? this.serverJobId,
      serverDraft: serverDraft ?? this.serverDraft,
      localPreview: localPreview ?? this.localPreview,
      notice: clearNotice ? null : notice ?? this.notice,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    step,
    role,
    category,
    area,
    details,
    companyInfo,
    shiftLabel,
    rateNpr,
    contactPhone,
    workingHours,
    employmentType,
    openings,
    salaryIncrement,
    incrementNote,
    compensationType,
    negotiable,
    googleMapsLink,
    latitude,
    longitude,
    locating,
    submitting,
    submitted,
    serverJobId,
    serverDraft,
    localPreview,
    notice,
    errorMessage,
  ];
}

class HiringRequisitionCubit extends Cubit<HiringWizardState> {
  HiringRequisitionCubit(this._client) : super(const HiringWizardState());

  final ApiClient _client;

  void setRole(String role) =>
      emit(state.copyWith(role: role, clearError: true));
  void setCategory(String category) =>
      emit(state.copyWith(category: category, clearError: true));
  void setArea(String area) =>
      emit(state.copyWith(area: area, clearError: true));
  void setDetails(String details) =>
      emit(state.copyWith(details: details, clearError: true));
  void setCompanyInfo(String companyInfo) =>
      emit(state.copyWith(companyInfo: companyInfo, clearError: true));
  void setShiftLabel(String shiftLabel) =>
      emit(state.copyWith(shiftLabel: shiftLabel, clearError: true));
  void setRateNpr(int rateNpr) =>
      emit(state.copyWith(rateNpr: rateNpr, clearError: true));
  void setContactPhone(String phone) =>
      emit(state.copyWith(contactPhone: phone, clearError: true));
  void setWorkingHours(String hours) =>
      emit(state.copyWith(workingHours: hours, clearError: true));
  void setEmploymentType(String type) =>
      emit(state.copyWith(employmentType: type, clearError: true));
  void setOpenings(int openings) =>
      emit(state.copyWith(openings: openings, clearError: true));
  void setSalaryIncrement(bool increment) =>
      emit(state.copyWith(salaryIncrement: increment, clearError: true));
  void setIncrementNote(String note) =>
      emit(state.copyWith(incrementNote: note, clearError: true));
  void setCompensationType(String type) =>
      emit(state.copyWith(compensationType: type, clearError: true));
  void setNegotiable(bool negotiable) =>
      emit(state.copyWith(negotiable: negotiable, clearError: true));

  // Named aliases used by the wizard. They emit the same state as the
  // canonical setters but keep widget code readable and atomic where two
  // fields change together.
  void setJobType(String title, String category) => emit(
    state.copyWith(role: title, category: category, clearError: true),
  );
  void setShift(String shift) =>
      emit(state.copyWith(shiftLabel: shift, clearError: true));
  void setRate(int rate) =>
      emit(state.copyWith(rateNpr: rate, clearError: true));

  void setGoogleMapsLink(String link) {
    final trimmed = link.trim();
    final parsed = MapLink.coordinates(trimmed);
    emit(
      state.copyWith(
        googleMapsLink: trimmed,
        latitude: parsed?.latitude ?? state.latitude,
        longitude: parsed?.longitude ?? state.longitude,
        clearError: true,
      ),
    );
  }

  /// True when a non-empty link is not a Google Maps URL or a coordinate pin.
  /// The wizard uses this for inline validation instead of failing at submit.
  bool get hasInvalidMapsLink => state.hasInvalidMapsLink;

  Future<void> openDirections() async {
    final uri = MapLink.directionsUri(
      link: state.googleMapsLink,
      latitude: state.latitude,
      longitude: state.longitude,
      area: state.area,
    );
    if (!await canLaunchUrl(uri)) {
      emit(state.copyWith(errorMessage: 'Google Maps could not be opened.'));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> useMyLocation() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true, clearError: true));
    try {
      final position = await getCurrentDevicePosition();
      if (isClosed) return;
      emit(
        state.copyWith(
          locating: false,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on DeviceLocationException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(locating: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          locating: false,
          errorMessage: 'Could not read your location.',
        ),
      );
    }
  }

  void next() {
    if (state.role.trim().length < 2) {
      emit(state.copyWith(errorMessage: 'Choose or type a job title.'));
      return;
    }
    if (state.area.trim().isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Add a work area so workers can find the shift.',
        ),
      );
      return;
    }
    switch (state.step) {
      case HiringStep.work:
        emit(state.copyWith(step: HiringStep.schedule, clearError: true));
      case HiringStep.schedule:
        emit(state.copyWith(step: HiringStep.budget, clearError: true));
      case HiringStep.budget:
        emit(state.copyWith(step: HiringStep.review, clearError: true));
      case HiringStep.review:
        submit();
    }
  }

  void previous() {
    switch (state.step) {
      case HiringStep.schedule:
        emit(state.copyWith(step: HiringStep.work, clearError: true));
      case HiringStep.budget:
        emit(state.copyWith(step: HiringStep.schedule, clearError: true));
      case HiringStep.review:
        emit(state.copyWith(step: HiringStep.budget, clearError: true));
      case HiringStep.work:
        break;
    }
  }

  void submitLocalPreview() {
    emit(
      state.copyWith(
        submitted: true,
        localPreview: true,
        clearServerJobId: true,
        serverDraft: false,
        notice: 'Local preview only. Nothing was sent to the server.',
        clearError: true,
      ),
    );
  }

  Future<void> submit() async {
    if (hasInvalidMapsLink) {
      emit(
        state.copyWith(
          errorMessage:
              'Use a Google Maps link (https://maps.app.goo.gl/…) or a pin like 27.7172, 85.3240 — or leave the field empty.',
        ),
      );
      return;
    }
    if (_client.accessToken == null) {
      submitLocalPreview();
      return;
    }
    emit(state.copyWith(submitting: true, clearError: true, clearNotice: true));
    try {
      final json = await _client.postJson(
        '/v1/jobs',
        body: {
          'role': state.role.trim(),
          'category': state.category,
          'description': state.composedDescription,
          'workMode': 'ON_SITE',
          'area': state.area.trim(),
          'latitude': state.latitude ?? 27.7172,
          'longitude': state.longitude ?? 85.3240,
          'dispatchRadiusKm': 10,
          'compensationType': state.compensationType,
          'rateNpr': state.rateNpr,
          'negotiable': state.negotiable,
          'employmentType': state.employmentType,
          'openings': state.openings,
          'salaryIncrement': state.salaryIncrement,
          if (state.contactPhone.trim().isNotEmpty)
            'contactPhone': state.contactPhone.trim(),
          if (state.workingHours.trim().isNotEmpty)
            'workingHours': state.workingHours.trim(),
          if (state.incrementNote.trim().isNotEmpty)
            'incrementNote': state.incrementNote.trim(),
          'requiredSkills': const <String>[],
          'qualifications': const <String>[],
        },
      );
      final job = json['job'];
      final id = job is Map<String, dynamic> ? job['id']?.toString() : null;

      // Jobs are created as DRAFT on the server and only PUBLISHED jobs show
      // up in worker discovery. Publish immediately, but NEVER hide a failure:
      // a swallowed error is exactly why jobs used to "disappear".
      final failure = id == null
          ? 'The server did not return a job id.'
          : await _publish(id);

      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          submitted: true,
          serverJobId: id,
          serverDraft: failure != null,
          notice: failure == null
              ? 'Shift published successfully! It is now live on the worker vacancy map.'
              : 'Saved on the server as a DRAFT — workers cannot see it yet. Publishing failed: $failure',
          errorMessage: failure,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          errorMessage: 'Not sent: ${error.message}',
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          errorMessage:
              'Could not reach the server. Nothing was sent — try again or use local preview.',
        ),
      );
    }
  }

  /// Returns null on success, or a human-readable reason on failure.
  Future<String?> _publish(String id) async {
    try {
      await _client.postJson('/v1/jobs/$id/publish');
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not reach the server.';
    }
  }

  /// Lets the hirer recover from a failed publish without re-posting the job.
  Future<void> retryPublish() async {
    final id = state.serverJobId;
    if (id == null || state.submitting) return;
    emit(state.copyWith(submitting: true, clearError: true));
    final failure = await _publish(id);
    if (isClosed) return;
    emit(
      state.copyWith(
        submitting: false,
        serverDraft: failure != null,
        notice: failure == null
            ? 'Shift published successfully! It is now live on the worker vacancy map.'
            : 'Still a draft: $failure',
        errorMessage: failure,
      ),
    );
  }

  void startAnother() => emit(const HiringWizardState());
}
