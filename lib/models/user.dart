enum UserRole { producer, cooperative, exporter, buyer, admin }

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.isDemo = false,
    this.pilotEndsAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;

  /// True when this account is a demo/QA account exempt from the pilot window.
  final bool isDemo;

  /// UTC timestamp when the 30-day pilot window closes. Null when the
  /// operator has not yet called `POST /v1/internal/pilots/start`.
  final DateTime? pilotEndsAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        phone: (json['phone'] as String?) ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.producer,
        ),
        isDemo: (json['isDemo'] as bool?) ?? false,
        pilotEndsAt: json['pilotEndsAt'] != null
            ? DateTime.parse(json['pilotEndsAt'] as String).toLocal()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phone': phone,
        'role': role.name,
        'isDemo': isDemo,
        if (pilotEndsAt != null)
          'pilotEndsAt': pilotEndsAt!.toUtc().toIso8601String(),
      };

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    bool? isDemo,
    DateTime? pilotEndsAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        isDemo: isDemo ?? this.isDemo,
        pilotEndsAt: pilotEndsAt ?? this.pilotEndsAt,
      );
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final User user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    if (json['success'] != true || json['data'] == null) {
      throw const FormatException(
        'Invalid API response: missing data envelope',
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return AuthResponse(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}
