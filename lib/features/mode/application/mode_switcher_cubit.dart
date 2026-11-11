import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

/// The active side of the marketplace.
///
/// The choice is made during sign-in and stays fixed afterwards; the profile
/// and the shell follow it. Single-role accounts are always locked to their own
/// side, while accounts that legitimately hold both roles keep the side they
/// picked when they signed in.
class ModeSwitcherCubit extends Cubit<AppMode> {
  ModeSwitcherCubit() : super(_restoreMode());

  static AppMode _restoreMode() =>
      SessionStore.appMode == 'hiring' ? AppMode.hiring : AppMode.vacancy;

  void toggle() {
    emit(state == AppMode.vacancy ? AppMode.hiring : AppMode.vacancy);
  }

  void select(AppMode mode) {
    if (mode == state) return;
    SessionStore.saveAppMode(mode == AppMode.hiring ? 'hiring' : 'vacancy');
    emit(mode);
  }

  /// Aligns the active side with the account's real roles only if no explicit
  /// login choice was made. The choice made at sign-in always takes priority.
  void applyAccount({required bool isWorker, required bool isEmployer}) {
    if (SessionStore.appMode != null) return;
    if (isWorker && !isEmployer) {
      select(AppMode.vacancy);
    } else if (isEmployer && !isWorker) {
      select(AppMode.hiring);
    }
  }
}
