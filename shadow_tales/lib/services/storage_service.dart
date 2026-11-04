import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_state.dart';

/// Local persistence for [PlayerState] (one save slot per story id).
/// For cloud-sync later, keep this interface and swap the implementation.
class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  String _key(String storyId) => 'save.$storyId';

  PlayerState? load(String storyId) {
    final raw = _prefs.getString(_key(storyId));
    if (raw == null) return null;
    try {
      return PlayerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted save -> caller starts fresh
    }
  }

  Future<void> save(String storyId, PlayerState s) =>
      _prefs.setString(_key(storyId), jsonEncode(s.toJson()));

  Future<void> clear(String storyId) => _prefs.remove(_key(storyId));
}
