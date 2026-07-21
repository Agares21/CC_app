import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);
final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref.watch(authRepositoryProvider))..restore(),
    );

class SessionState {
  const SessionState({
    this.user,
    this.isBootstrapping = false,
    this.isLoading = false,
    this.error,
  });
  final AppUser? user;
  final bool isBootstrapping;
  final bool isLoading;
  final String? error;
  SessionState copyWith({
    AppUser? user,
    bool? isBootstrapping,
    bool? isLoading,
    String? error,
    bool clearUser = false,
  }) => SessionState(
    user: clearUser ? null : user ?? this.user,
    isBootstrapping: isBootstrapping ?? this.isBootstrapping,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._repository)
    : super(const SessionState(isBootstrapping: true));
  final AuthRepository _repository;

  Future<void> restore() async =>
      state = SessionState(user: await _repository.restore());
  Future<void> login(String email, String password) async {
    state = const SessionState(isLoading: true);
    try {
      state = SessionState(user: await _repository.login(email, password));
    } catch (error) {
      state = SessionState(error: apiError(error));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const SessionState();
  }
}
