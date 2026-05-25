import 'dart:convert';

/// Parses the `exp` claim of a JWT and returns it as a UTC [DateTime], or
/// `null` if the token is malformed or the claim is missing/invalid.
///
/// v1.9.11 — used by [AuthNotifier.build] on cold-start to decide whether
/// the locally cached session is worth trusting for the first frame BEFORE
/// the asynchronous server probe completes (offline-friendly cold start).
///
/// IMPORTANT — security note. This function does NOT verify the JWT
/// signature. It only decodes the payload so the client can make a cheap
/// heuristic about whether the token has any chance of being accepted by
/// the server. Every real authenticated request still goes through the
/// backend, which validates the signature and rejects rotated/revoked
/// secrets on the next round trip. The client-side `exp` check exists only
/// to avoid bouncing the user back to the login screen when they re-open
/// the app at a remote plot without network coverage.
DateTime? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// Returns `true` when the JWT's `exp` claim is in the past (or unreadable),
/// applying a [skew] buffer so a token that is about to expire is treated
/// as expired. Defaults to a conservative 30 s skew.
///
/// A malformed token or one missing the `exp` claim is treated as expired
/// — we cannot trust it for the offline-friendly fast path. The caller is
/// expected to fall back to the active server probe in that case.
bool jwtIsExpired(String token, {Duration skew = const Duration(seconds: 30)}) {
  final exp = jwtExpiry(token);
  if (exp == null) return true;
  return DateTime.now().toUtc().isAfter(exp.subtract(skew));
}
