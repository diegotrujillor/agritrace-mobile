import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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
    final storage = ref.read(storageServiceProvider);
    final token = await storage.getAccessToken();
    if (token == null) return const AuthUnauthenticated();

    // Client-side JWT shape + expiry check. Heuristic to avoid treating an
    // expired or malformed token as a valid session on cold start. The
    // authoritative validation is server-side; Sprint 2 replaces this with
    // `GET /auth/me`.
    if (!_isJwtStillValid(token)) {
      await storage.deleteTokens();
      return const AuthUnauthenticated();
    }

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

/// Returns true if the token is well-formed and the `exp` claim is in the
/// future. Returns false for malformed tokens, missing `exp`, or expired.
bool _isJwtStillValid(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final exp = json['exp'];
    if (exp is! int) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return expiresAt.isAfter(DateTime.now());
  } catch (_) {
    return false;
  }
}
