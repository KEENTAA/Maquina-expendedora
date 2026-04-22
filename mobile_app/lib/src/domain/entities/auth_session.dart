class AuthSession {
  final String accessToken;
  final String email;
  final String role;
  final String? simupayEmail;

  const AuthSession({
    required this.accessToken,
    required this.email,
    required this.role,
    this.simupayEmail,
  });
}
