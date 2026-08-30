/// An authenticated app session, minted by the backend (`/auth/apple`) after it
/// verifies a Sign in with Apple identity token, and renewed by `/auth/refresh`.
/// The [token] is opaque to the app — it's sent as a Bearer `Authorization`
/// header on every authenticated call.
class Session {
  const Session({
    required this.token,
    required this.userId,
    required this.expiresAt,
    this.email,
    this.issuedAt,
  });

  final String token;

  /// Stable per-user id, e.g. `apple:000123.abc`.
  final String userId;

  /// The user's email, if Apple shared it (typically only on first sign-in).
  final String? email;

  final DateTime expiresAt;

  /// When [token] was minted or last renewed. Null for a session stored by a
  /// build that predates renewal — treated as "old enough to renew now".
  final DateTime? issuedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'email': email,
    'expiresAt': expiresAt.toIso8601String(),
    'issuedAt': issuedAt?.toIso8601String(),
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    userId: json['userId'] as String,
    email: json['email'] as String?,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    issuedAt: json['issuedAt'] is String
        ? DateTime.tryParse(json['issuedAt'] as String)
        : null,
  );
}
