import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const _ipKey = 'server_ip';

  Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
  }

  Future<String?> readIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipKey);
  }
}
