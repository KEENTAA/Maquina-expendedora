import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  final ProfileRepository _profileRepository;

  UserProfile? profile;
  bool loading = false;
  String? error;

  ProfileController({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository;

  Future<void> load(String email) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _profileRepository.load(email);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateName(String name) async {
    final current = profile;
    if (current == null) return;
    final updated = current.copyWith(displayName: name.trim());
    profile = await _profileRepository.save(updated);
    notifyListeners();
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    final current = profile;
    if (current == null) return;
    final updated = current.copyWith(avatarBase64: base64Encode(bytes));
    profile = await _profileRepository.save(updated);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    final current = profile;
    if (current == null) return;
    final updated = current.copyWith(clearAvatar: true);
    profile = await _profileRepository.save(updated);
    notifyListeners();
  }
}
