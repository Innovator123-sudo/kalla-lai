import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  void select(Locale locale) {
    if (locale.languageCode == 'en' || locale.languageCode == 'ne') {
      emit(locale);
    }
  }
}
