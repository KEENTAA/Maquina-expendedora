import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  @override
  Future<UserProfile> load(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey(email));
    final avatar = prefs.getString(_avatarKey(email));
    return UserProfile(
      email: email,
      displayName:
          (name == null || name.trim().isEmpty) ? email.split('@').first : name,
      avatarBase64: avatar,
    );
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey(profile.email), profile.displayName);
    if (profile.avatarBase64 == null || profile.avatarBase64!.isEmpty) {
      await prefs.remove(_avatarKey(profile.email));
    } else {
      await prefs.setString(_avatarKey(profile.email), profile.avatarBase64!);
    }
    return profile;
  }

  String _nameKey(String email) => 'profile_name_$email';
  String _avatarKey(String email) => 'profile_avatar_$email';
}
