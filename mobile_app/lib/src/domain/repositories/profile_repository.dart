import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> load(String email);
  Future<UserProfile> save(UserProfile profile);
}
