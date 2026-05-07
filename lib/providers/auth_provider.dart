import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>(
  (ref) => const StorageService(FlutterSecureStorage()),
);

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.read(storageServiceProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.read(apiServiceProvider),
    ref.read(storageServiceProvider),
  ),
);

sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(storageServiceProvider).getAccessToken();
    if (token == null) return const AuthUnauthenticated();
    // Token present — full profile fetch deferred to Sprint 2.
    // The empty-string fields below are an intentional placeholder so the
    // router can treat the session as authenticated on cold start without
    // an extra round-trip; the real profile arrives from /auth/me.
    // TODO(sprint-2): replace with GET /auth/me
    return const AuthAuthenticated(
      User(id: '', email: '', fullName: '', phone: '', role: UserRole.producer),
    );
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      return AuthAuthenticated(auth.user);
    });
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await ref.read(authServiceProvider).register(
            fullName: fullName,
            phone: phone,
            email: email,
            password: password,
          );
      return AuthAuthenticated(auth.user);
    });
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(AuthUnauthenticated());
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
