import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStore {
  static const _k = "app_settings_v1";

  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return AppSettings();
    return AppSettings.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(s.toMap()));
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }
}
