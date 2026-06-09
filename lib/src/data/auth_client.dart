import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/session.dart';

/// Thrown when the user dismisses the native Sign in with Apple sheet — the UI
/// should treat this as a no-op, not an error.
class SignInCancelled implements Exception {}

/// A user-facing sign-in failure (network / backend rejection). [message] is
/// safe to show directly.
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// Signs the user in with Apple and exchanges the resulting identity token for
/// our own app [Session] via the backend `/auth/apple` endpoint.
class AuthClient {
  AuthClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Same base URL as the vision proxy; `/auth/apple` lives on the same API.
  final String baseUrl;
  final http.Client _http;

  Uri get endpoint {
    final base =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base/auth/apple');
  }

  /// Runs the native Apple flow, then exchanges the identity token for a
  /// [Session]. Throws [SignInCancelled] if the user aborts, or [AuthException]
  /// on a backend/network failure.
  Future<Session> signInWithApple() async {
    final rawNonce = _randomNonce();
    // Apple embeds this hash in the identity token's `nonce` claim; the server
    // re-hashes the raw nonce we send and compares — guards against replay.
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SignInCancelled();
      throw AuthException('Could not sign in with Apple. Please try again.');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw AuthException('Apple did not return an identity token.');
    }

    final fullName = [credential.givenName, credential.familyName]
        .whereType<String>()
        .join(' ')
        .trim();

    return exchange(
      identityToken: identityToken,
      rawNonce: rawNonce,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }

  /// Exchanges a verified Apple [identityToken] (+ the raw nonce) for a
  /// [Session]. Pure HTTP — unit-tested with a mock client.
  Future<Session> exchange({
    required String identityToken,
    required String rawNonce,
    String? fullName,
  }) async {
    final http.Response resp;
    try {
      resp = await _http.post(
        endpoint,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'identityToken': identityToken,
          'rawNonce': rawNonce,
          'fullName': ?fullName,
        }),
      );
    } catch (_) {
      throw AuthException('Network error — check your connection.');
    }

    if (resp.statusCode != 200) {
      throw _authError(resp.statusCode, resp.body);
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final expiresInSeconds = (json['expiresInSeconds'] as num?)?.toInt() ?? 0;
    return Session(
      token: json['sessionToken'] as String,
      userId: json['userId'] as String,
      email: json['email'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

AuthException _authError(int statusCode, String body) {
  String message;
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final err = json['error'];
    message = (err is Map && err['message'] is String)
        ? err['message'] as String
        : 'Sign-in failed. Please try again.';
  } catch (_) {
    message = 'Sign-in failed. Please try again.';
  }
  return AuthException(message, statusCode: statusCode);
}
