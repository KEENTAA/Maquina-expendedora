class UserProfile {
  final String email;
  final String displayName;
  final String? avatarBase64;

  const UserProfile({
    required this.email,
    required this.displayName,
    this.avatarBase64,
  });

  UserProfile copyWith({
    String? displayName,
    String? avatarBase64,
    bool clearAvatar = false,
  }) {
    return UserProfile(
      email: email,
      displayName: displayName ?? this.displayName,
      avatarBase64: clearAvatar ? null : (avatarBase64 ?? this.avatarBase64),
    );
  }
}
