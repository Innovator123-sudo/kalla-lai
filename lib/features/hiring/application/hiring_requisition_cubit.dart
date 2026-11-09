import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/location/device_location.dart';
import 'package:kalla_lai/core/networking/api_client.dart';

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

  String get composedDescription {
    final parts = <String>[];
    final trimmedDetails = details.trim();
    if (trimmedDetails.length >= 10) parts.add(trimmedDetails);
    final trimmedCompany = companyInfo.trim();
    if (trimmedCompany.isNotEmpty) parts.add('About us: $trimmedCompany');
    if (parts.isNotEmpty) return parts.join('\n\n');
    return '$role needed in $area. Shift window: $shiftLabel.';
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

  void setRole(String value) =>
      emit(state.copyWith(role: value, clearError: true));
  void setJobType(String title, String category) =>
      emit(state.copyWith(role: title, category: category, clearError: true));
  void setArea(String value) =>
      emit(state.copyWith(area: value, clearError: true));
  void setDetails(String value) =>
      emit(state.copyWith(details: value, clearError: true));
  void setCompanyInfo(String value) =>
      emit(state.copyWith(companyInfo: value, clearError: true));
  void setShift(String value) =>
      emit(state.copyWith(shiftLabel: value, clearError: true));
  void setRate(int value) =>
      emit(state.copyWith(rateNpr: value, clearError: true));
  void setContactPhone(String value) =>
      emit(state.copyWith(contactPhone: value, clearError: true));
  void setWorkingHours(String value) =>
      emit(state.copyWith(workingHours: value, clearError: true));
  void setEmploymentType(String value) =>
      emit(state.copyWith(employmentType: value, clearError: true));
  void setOpenings(int value) =>
      emit(state.copyWith(openings: value.clamp(1, 1000), clearError: true));
  void setSalaryIncrement(bool value) =>
      emit(state.copyWith(salaryIncrement: value, clearError: true));
  void setIncrementNote(String value) =>
      emit(state.copyWith(incrementNote: value, clearError: true));
  void setCompensationType(String value) =>
      emit(state.copyWith(compensationType: value, clearError: true));
  void setNegotiable(bool value) =>
      emit(state.copyWith(negotiable: value, clearError: true));

  Future<void> useMyLocation() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true, clearError: true));
    try {
      final position = await getCurrentDevicePosition();
      if (isClosed) return;
      emit(
        state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          locating: false,
          notice: 'True location captured for this job.',
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

  /// Explicit "no server call" request from the UI. Always produces a local
  /// preview and never touches the network or pretends anything was published.
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

  /// Sends the requisition to the API when a session token exists.
  ///
  /// The server decides whether the caller may post (EMPLOYER role) and always
  /// stores the result as a DRAFT — nothing is published from the client.
  Future<void> submit() async {
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
          // True device location when captured; otherwise an approximate
          // city-centre pin. Exact address stays an employer decision later.
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
      final status =
          job is Map<String, dynamic> ? job['status']?.toString() : null;
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          submitted: true,
          serverJobId: id,
          serverDraft: status != 'PUBLISHED',
          notice:
              'Saved on the server as a draft. Publish it from the employer console to make it discoverable.',
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

  void startAnother() => emit(const HiringWizardState());
}