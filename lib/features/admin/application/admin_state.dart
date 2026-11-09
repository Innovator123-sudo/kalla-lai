import 'package:equatable/equatable.dart';
import 'package:kalla_lai/core/config/supabase_config.dart';

import 'admin_models.dart';

/// The admin console's "People" directory state.
class AdminPeopleState extends Equatable {
  const AdminPeopleState({
    this.status = AdminLoadStatus.loading,
    this.people = const [],
    this.query = '',
    this.roleFilter = 'ALL',
    this.savingIds = const {},
    this.errorMessage,
    this.supabase = SupabaseSettings.empty,
  });

  final AdminLoadStatus status;
  final List<AdminPerson> people;
  final String query;
  final String roleFilter;

  /// Account ids with an in-flight write, so a row can show progress.
  final Set<String> savingIds;
  final String? errorMessage;

  /// Runtime backend settings, so staff can see whether the console is editing
  /// Supabase Postgres or the local development engine.
  final SupabaseSettings supabase;

  bool get isLoading => status == AdminLoadStatus.loading;

  AdminPeopleState copyWith({
    AdminLoadStatus? status,
    List<AdminPerson>? people,
    String? query,
    String? roleFilter,
    Set<String>? savingIds,
    String? errorMessage,
    SupabaseSettings? supabase,
    bool clearError = false,
  }) => AdminPeopleState(
    status: status ?? this.status,
    people: people ?? this.people,
    query: query ?? this.query,
    roleFilter: roleFilter ?? this.roleFilter,
    savingIds: savingIds ?? this.savingIds,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    supabase: supabase ?? this.supabase,
  );

  @override
  List<Object?> get props => [
    status,
    people,
    query,
    roleFilter,
    savingIds,
    errorMessage,
    supabase,
  ];
}

enum AdminLoadStatus { loading, ready, error }
