class UserMe {
  final int id;
  final String username;
  final String email;
  final bool isStaff;
  final int cardCount;
  final String? avatarUrl;

  UserMe({
    required this.id,
    required this.username,
    required this.email,
    required this.isStaff,
    required this.cardCount,
    this.avatarUrl,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isStaff: json['is_staff'] as bool? ?? false,
      cardCount: json['card_count'] as int? ?? 0,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'is_staff': isStaff,
    'card_count': cardCount,
    'avatar_url': avatarUrl,
  };
}

class AuthResponse {
  final String token;
  final String? username;

  AuthResponse({required this.token, this.username});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      username: json['username'] as String?,
    );
  }
}
