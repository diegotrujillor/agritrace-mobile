import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'database_provider.dart';

/// `flutter_secure_storage` backed by:
///  - iOS: Keychain (`first_unlock_this_device`)
///  - Android: EncryptedSharedPreferences (AES-256, forced on)
///  - macOS: Keychain
/// Web target is explicitly unsupported — `localStorage` is unencrypted
/// and would leak tokens to any JS on the same origin.
final storageServiceProvider = Provider<StorageService>((ref) {
  if (kIsWeb) {
    throw UnsupportedError(
      'AgriTrace mobile does not support the web target — tokens cannot '
      'be stored securely in browser localStorage.',
    );
  }
  return const StorageService(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});

/// Wires [ApiService] with an `onLogout` callback so the interceptor can
/// flip the auth state to [AuthUnauthenticated] when it detects an
/// unrecoverable refresh failure (i.e. the session has collapsed and the
/// router needs to bounce the user back to `/login`).
final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(
    ref.read(storageServiceProvider),
    onLogout: () {
      // The notifier may not have been built yet during very early cold-start
      // refresh failures; reading the notifier is safe — it will be created
      // lazily, and the state assignment is a no-op until the first read.
      ref.read(authProvider.notifier).markUnauthenticated();
    },
  ),
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
    final storage = ref.read(storageServiceProvider);
    final accessToken = await storage.getAccessToken();
    if (accessToken == null) return const AuthUnauthenticated();
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) return const AuthUnauthenticated();

    // Active cold-start probe: hit `/auth/refresh` with the stored refresh
    // token. This is the lightest authenticated endpoint that proves both
    // (a) the refresh token is still alive server-side and (b) the JWT
    // secret has not been rotated. The previous client-only `exp` check
    // could not detect either condition, so a user could land on the
    // dashboard with a session the server would reject on the first
    // domain call — surfacing as "Credenciales incorrectas" banners.
    //
    // Backend has no `/auth/me` (see agritrace-backend/src/api/auth/auth.routes.ts);
    // `refresh()` is the closest equivalent and is rate-limited (`authLimiter`).
    try {
      final auth = await ref.read(authServiceProvider).refresh();
      // Seed local DB with server data on cold start. Fire-and-forget so a
      // network failure does not block the app from reaching the dashboard.
      _seedInBackground('initial seed');
      return AuthAuthenticated(auth.user);
    } on DioException catch (e) {
      // 401/403 → refresh token rejected → unrecoverable. Any other status
      // (5xx, network) → assume transient and treat as unauthenticated for
      // this cold start; the user can retry. Either way: do not crash.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await storage.deleteTokens();
      }
      return const AuthUnauthenticated();
    } on StateError {
      // refresh() guards on a missing token — should not happen here because
      // we already null-checked above, but treat defensively.
      return const AuthUnauthenticated();
    } catch (_) {
      // Malformed envelope, etc. Fail closed.
      await storage.deleteTokens();
      return const AuthUnauthenticated();
    }
  }

  /// Runs a sync round trip in the background, swallowing errors.
  ///
  /// Used to seed the local DB after authentication without blocking the
  /// login/cold-start flow.  Errors are logged but not surfaced.
  void _seedInBackground(String context) {
    ref.read(syncOrchestratorProvider).run().then((_) {}).catchError((Object e) {
      dev.log('AuthNotifier: $context sync failed: $e', name: 'auth');
    });
  }

  /// Flips the state to [AuthUnauthenticated] without going through
  /// [logout()] — used by the [ApiService] `onLogout` callback when the
  /// refresh interceptor detects an unrecoverable session collapse.
  void markUnauthenticated() {
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Drops any [AsyncError] currently held by the notifier without changing
  /// the underlying auth status.
  ///
  /// v1.9.0 — fixes bug #4: a failed login (e.g. "Credenciales incorrectas")
  /// leaves the error banner glued to the auth state, and `LoginScreen` keeps
  /// re-rendering it even after the user has fixed their input. The screens
  /// call this from `onChanged` to wipe the banner the moment the user types
  /// in the email or password field.
  ///
  /// Idempotent: when the state is already `data` this is a no-op so the
  /// notifier never publishes a redundant frame.
  void clearError() {
    final current = state;
    if (current is! AsyncError) return;
    // Preserve the underlying value if there was one (e.g. an
    // authenticated user whose subsequent token refresh errored); fall
    // back to "unauthenticated" when none was held.
    final preserved = current.valueOrNull ?? const AuthUnauthenticated();
    state = AsyncData(preserved);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      // Seed local DB on fresh login. Fire-and-forget.
      _seedInBackground('login seed');
      return AuthAuthenticated(auth.user);
    });
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required bool privacyConsent,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final auth = await ref.read(authServiceProvider).register(
            fullName: fullName,
            phone: phone,
            email: email,
            password: password,
            privacyConsent: privacyConsent,
          );
      // New account — local DB is empty; seed attempt is a no-op but
      // marks the pattern consistent with login.
      _seedInBackground('register seed');
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
