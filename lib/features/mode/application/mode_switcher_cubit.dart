import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class ModeSwitcherCubit extends Cubit<AppMode> {
  ModeSwitcherCubit() : super(AppMode.vacancy);

  void toggle() {
    emit(state == AppMode.vacancy ? AppMode.hiring : AppMode.vacancy);
  }

  void select(AppMode mode) {
    if (mode != state) emit(mode);
  }
}
