import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/networking/api_client.dart';

/// The two ways someone can enter Kalla-Lai. This is a product choice, not an
/// authorization grant: the API always decides what an account may do.
enum EntryIntent { worker, employer }

extension EntryIntentLabels on EntryIntent {
  String get apiValue => this == EntryIntent.employer ? 'EMPLOYER' : 'WORKER';

  String get title =>
      this == EntryIntent.employer ? 'I want to hire' : 'I want to work';

  String get subtitle =>
      this == EntryIntent.employer
          ? 'Post shifts and find verified workers near you.'
          : 'Find shifts near you and get paid for your work.';

  String get continueLabel =>
      this == EntryIntent.employer
          ? 'Continue as employer'
          : 'Continue as worker';
}

/// Navigation state for the first-run journey:
/// splash → intent → survey → sign-in → profile/verification → home.
class EntryJourneyState extends Equatable {
  const EntryJourneyState({
    this.intent,
    this.surveyComplete = false,
    this.acquisitionSource,
    this.timeline,
    this.experience,
    this.staffLogin = false,
    this.identitySkipped = false,
    this.surveySyncing = false,
    this.surveySynced = false,
    this.surveyError,
  });

  final EntryIntent? intent;
  final bool surveyComplete;
  final String? acquisitionSource;
  final String? timeline;
  final String? experience;

  /// Lets platform staff reach the sign-in menu without answering the
  /// worker/employer questions. The server still enforces their real roles.
  final bool staffLogin;

  /// Set when someone chooses "Skip for now" on the identity check. It only
  /// hides the blocking screen — applying stays locked until the API reports
  /// `identityStatus == 'VERIFIED'`.
  final bool identitySkipped;

  final bool surveySyncing;
  final bool surveySynced;
  final String? surveyError;

  bool get surveyAnswered =>
      acquisitionSource != null && timeline != null && experience != null;

  Map<String, dynamic>? get surveyJson {
    if (!surveyAnswered) return null;
    return {
      'intent': intent?.apiValue ?? 'WORKER',
      'acquisitionSource': acquisitionSource,
      'timeline': timeline,
      'experience': experience,
    };
  }

  EntryJourneyState copyWith({
    EntryIntent? intent,
    bool clearIntent = false,
    bool? surveyComplete,
    String? acquisitionSource,
    String? timeline,
    String? experience,
    bool? staffLogin,
    bool? identitySkipped,
    bool? surveySyncing,
    bool? surveySynced,
    String? surveyError,
    bool clearSurveyError = false,
  }) => EntryJourneyState(
    intent: clearIntent ? null : intent ?? this.intent,
    surveyComplete: surveyComplete ?? this.surveyComplete,
    acquisitionSource: acquisitionSource ?? this.acquisitionSource,
    timeline: timeline ?? this.timeline,
    experience: experience ?? this.experience,
    staffLogin: staffLogin ?? this.staffLogin,
    identitySkipped: identitySkipped ?? this.identitySkipped,
    surveySyncing: surveySyncing ?? this.surveySyncing,
    surveySynced: surveySynced ?? this.surveySynced,
    surveyError: clearSurveyError ? null : surveyError ?? this.surveyError,
  );

  @override
  List<Object?> get props => [
    intent,
    surveyComplete,
    acquisitionSource,
    timeline,
    experience,
    staffLogin,
    identitySkipped,
    surveySyncing,
    surveySynced,
    surveyError,
  ];
}

class EntryJourneyCubit extends Cubit<EntryJourneyState> {
  EntryJourneyCubit(this._client) : super(const EntryJourneyState());

  final ApiClient _client;

  void chooseIntent(EntryIntent intent) {
    // Re-answering the first question resets any earlier survey answers so the
    // stored intent and survey never contradict each other.
    emit(EntryJourneyState(intent: intent));
  }

  void completeSurvey({
    required String acquisitionSource,
    required String timeline,
    required String experience,
  }) {
    emit(
      state.copyWith(
        surveyComplete: true,
        acquisitionSource: acquisitionSource,
        timeline: timeline,
        experience: experience,
      ),
    );
  }

  void skipSurvey() => emit(state.copyWith(surveyComplete: true));

  void beginStaffLogin() =>
      emit(const EntryJourneyState(staffLogin: true, surveyComplete: true));

  /// Back to the first question. Also clears identity skip so a different
  /// person signing in on the same device starts clean.
  void changeIntent() => emit(const EntryJourneyState());

  void skipIdentity() => emit(state.copyWith(identitySkipped: true));

  void resetIdentitySkip() => emit(state.copyWith(identitySkipped: false));

  /// Clears per-session flags when a user signs out but keeps their answers so
  /// the next person on this device is not shown a stale survey result.
  void resetForSignOut() => emit(
    state.copyWith(
      identitySkipped: false,
      surveySynced: false,
      surveySyncing: false,
      clearSurveyError: true,
    ),
  );

  /// Sends the optional survey once, after the API has issued a session.
  /// Failures never block the app; they stay visible in state for retry.
  Future<void> syncSurvey() async {
    if (!AppConfig.liveApiEnabled ||
        state.surveySynced ||
        state.surveySyncing ||
        _client.accessToken == null) {
      return;
    }
    final payload = state.surveyJson;
    if (payload == null) return;

    emit(state.copyWith(surveySyncing: true, clearSurveyError: true));
    try {
      await _client.postJson('/v1/entry/survey', body: payload);
      if (isClosed) return;
      emit(state.copyWith(surveySyncing: false, surveySynced: true));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(surveySyncing: false, surveyError: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          surveySyncing: false,
          surveyError: 'Survey answers could not reach the server.',
        ),
      );
    }
  }
}
