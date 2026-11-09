import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/supabase_config.dart';
import 'package:kalla_lai/core/networking/api_client.dart';

import 'admin_models.dart';
import 'admin_state.dart';

/// Staff-only console for browsing every account and configuring its profile:
/// account fields, roles, and the worker / employer profile sheets.
class AdminCubit extends Cubit<AdminPeopleState> {
  AdminCubit(this._client) : super(const AdminPeopleState());

  final ApiClient _client;
  Timer? _debounce;

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  /// First load when the console opens (or retry after an error).
  Future<void> load() async {
    emit(
      state.copyWith(
        status: AdminLoadStatus.loading,
        people: const [],
        clearError: true,
      ),
    );
    await _loadRuntimeConfig();
    await _fetch(keepPeople: false);
  }

  /// Reads the public, client-safe Supabase settings so the console can show
  /// which backend it is actually editing. Failure never blocks the directory.
  Future<void> _loadRuntimeConfig() async {
    try {
      final json = await _client.getJson('/v1/app/config');
      if (isClosed) return;
      emit(state.copyWith(supabase: SupabaseSettings.fromAppConfig(json)));
    } catch (_) {
      // Keep the default "Local engine" label when config is unreachable.
    }
  }

  /// Called on every keystroke; debounced so typing does not hammer the API.
  void onQueryChanged(String value) {
    _debounce?.cancel();
    emit(state.copyWith(query: value));
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      emit(state.copyWith(status: AdminLoadStatus.loading, clearError: true));
      await _fetch(keepPeople: false);
    });
  }

  void selectRoleFilter(String role) {
    if (role == state.roleFilter) return;
    emit(state.copyWith(roleFilter: role));
    _debounce?.cancel();
    _refetch(changedFilter: true);
  }

  /// Refreshes without clearing the visible people (pull-to-refresh).
  Future<void> refresh() async => _refetch(changedFilter: false);

  Future<void> _refetch({required bool changedFilter}) async {
    emit(
      state.copyWith(
        status: AdminLoadStatus.loading,
        // When only the filter/search changed, clear the list so a failed
        // refresh does not silently show stale rows for the wrong query.
        people: changedFilter ? const [] : state.people,
        clearError: true,
      ),
    );
    await _fetch(keepPeople: !changedFilter);
  }

  Future<void> _fetch({required bool keepPeople}) async {
    try {
      final result = await _client.getJson('/v1/admin/people', query: {
        'limit': '60',
        if (state.roleFilter != 'ALL') 'role': state.roleFilter,
        if (state.query.trim().isNotEmpty) 'q': state.query.trim(),
      });
      if (isClosed) return;
      final people =
          ((result['people'] as List<Object?>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AdminPerson.fromJson)
              .toList(growable: false);
      emit(state.copyWith(status: AdminLoadStatus.ready, people: people));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminLoadStatus.error,
          errorMessage: error.message,
          people: keepPeople ? state.people : const [],
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: AdminLoadStatus.error,
          errorMessage: 'Could not reach the Kalla-Lai API. Try again.',
          people: keepPeople ? state.people : const [],
        ),
      );
    }
  }

  /// Saves an edited person. The patch keys mirror the server schema:
  /// `user`, `workerProfile`, `employerProfile` — each may be partial.
  Future<bool> savePerson(String id, Map<String, dynamic> patch) async {
    if (state.savingIds.contains(id)) return false;
    _markSaving(id);
    try {
      final result = await _client.patchJson('/v1/admin/people/$id', body: patch);
      _applyPersonResult(result, id);
      return true;
    } on ApiException catch (error) {
      _fail(error.message, id);
      return false;
    } catch (_) {
      _fail('Saving failed. Check the connection and try again.', id);
      return false;
    }
  }

  /// Creates a worker or hirer profile sheet for an account that has none.
  /// Idempotent server-side, so configuring twice is harmless.
  Future<bool> configureProfile(String id, String kind) async {
    if (state.savingIds.contains(id)) return false;
    _markSaving(id);
    try {
      final result = await _client.postJson(
        '/v1/admin/people/$id/profiles/$kind',
        body: const <String, dynamic>{},
      );
      _applyPersonResult(result, id);
      return true;
    } on ApiException catch (error) {
      _fail(error.message, id);
      return false;
    } catch (_) {
      _fail('Could not create the profile. Check the connection and try again.', id);
      return false;
    }
  }

  /// Removes a worker or hirer profile sheet from an account.
  Future<bool> removeProfile(String id, String kind) async {
    if (state.savingIds.contains(id)) return false;
    _markSaving(id);
    try {
      final result = await _client.deleteJson('/v1/admin/people/$id/profiles/$kind');
      _applyPersonResult(result, id);
      return true;
    } on ApiException catch (error) {
      _fail(error.message, id);
      return false;
    } catch (_) {
      _fail('Could not remove the profile. Check the connection and try again.', id);
      return false;
    }
  }

  void _markSaving(String id) {
    emit(state.copyWith(
      savingIds: {...state.savingIds, id},
      clearError: true,
    ));
  }

  void _applyPersonResult(Map<String, dynamic> result, String id) {
    if (isClosed) return;
    final updated = result['person'];
    if (updated is Map<String, dynamic>) {
      final refreshed = AdminPerson.fromJson(updated);
      final people = [
        for (final person in state.people)
          if (person.id == id) refreshed else person,
      ];
      emit(state.copyWith(people: people, savingIds: _withoutSaving(id)));
    } else {
      emit(state.copyWith(savingIds: _withoutSaving(id)));
    }
  }

  void _fail(String message, String id) {
    if (isClosed) return;
    emit(state.copyWith(
      errorMessage: message,
      savingIds: _withoutSaving(id),
    ));
  }

  Set<String> _withoutSaving(String id) => {
    for (final value in state.savingIds)
      if (value != id) value,
  };
}
