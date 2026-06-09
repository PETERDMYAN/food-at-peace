/// An authenticated app session, minted by the backend (`/auth/apple`) after it
/// verifies a Sign in with Apple identity token. The [token] is opaque to the
/// app — it's sent as `Authorization: Bearer <token>` on every `/sync` call.
class Session {
  const Session({
    required this.token,
    required this.userId,
    required this.expiresAt,
    this.email,
  });

  final String token;

  /// Stable per-user id, e.g. `apple:000123.abc`.
  final String userId;

  /// The user's email, if Apple shared it (typically only on first sign-in).
  final String? email;

  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'email': email,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        userId: json['userId'] as String,
        email: json['email'] as String?,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
