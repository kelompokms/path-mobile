class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class AuthSuccessResponse {
  final String token;

  const AuthSuccessResponse({required this.token});

  factory AuthSuccessResponse.fromJson(Map<String, dynamic> json) {
    return AuthSuccessResponse(
      token: json['token'] as String? ?? '',
    );
  }
}
