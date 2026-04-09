import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/mac_portal_client.dart';

enum PreferredPlayer { builtin, mxplayer, vlcExternal }

class SavedProfile {
  final String name;
  final String url;
  final String mac;

  SavedProfile({required this.name, required this.url, required this.mac});

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'mac': mac};

  factory SavedProfile.fromJson(Map<String, dynamic> json) {
    return SavedProfile(
      name: json['name'] ?? 'My Playlist',
      url: json['url'] ?? '',
      mac: json['mac'] ?? '',
    );
  }
}

class AppState extends ChangeNotifier {
  String? _playlistName;
  MacPortalClient? _client;
  List<SavedProfile> _profiles = [];
  int? _activeProfileIndex;
  PreferredPlayer _preferredPlayer = PreferredPlayer.builtin;
  bool _subtitlesEnabled = true;

  // Getters
  String get playlistName => _playlistName ?? '';
  bool get isLoggedIn => _client != null;
  MacPortalClient? get client => _client;
  List<SavedProfile> get profiles => _profiles;
  int? get activeProfileIndex => _activeProfileIndex;
  PreferredPlayer get preferredPlayer => _preferredPlayer;
  bool get subtitlesEnabled => _subtitlesEnabled;

  // Storage keys
  static const String _keyProfiles = 'saved_profiles_list';
  static const String _keyPlayer = 'preferred_player';
  static const String _keySubs = 'subtitles_enabled';

  /// Load all saved profiles and settings from disk. Does NOT auto-connect.
  Future<void> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();

    // Load profiles
    final raw = prefs.getString(_keyProfiles);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(raw);
        _profiles = jsonList
            .map((e) => SavedProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _profiles = [];
      }
    }

    // Migrate old single-profile keys if multi-profile list is empty
    if (_profiles.isEmpty) {
      final oldUrl = prefs.getString('cache_server_url');
      final oldMac = prefs.getString('cache_mac_address');
      if (oldUrl != null && oldUrl.isNotEmpty && oldMac != null && oldMac.isNotEmpty) {
        final oldName = prefs.getString('cache_playlist_name') ?? 'My Playlist';
        _profiles.add(SavedProfile(name: oldName, url: oldUrl, mac: oldMac));
        await _saveProfiles();
        // Clean up old keys
        await prefs.remove('cache_playlist_name');
        await prefs.remove('cache_server_url');
        await prefs.remove('cache_mac_address');
      }
    }

    // Load player settings
    final playerStr = prefs.getString(_keyPlayer);
    if (playerStr != null) {
      _preferredPlayer = PreferredPlayer.values.firstWhere(
        (e) => e.name == playerStr,
        orElse: () => PreferredPlayer.builtin,
      );
    }
    _subtitlesEnabled = prefs.getBool(_keySubs) ?? true;

    notifyListeners();
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_keyProfiles, json.encode(jsonList));
  }

  /// Add a new profile and save it.
  Future<void> addProfile(SavedProfile profile) async {
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
  }

  /// Delete a profile by index.
  Future<void> deleteProfile(int index) async {
    if (index < 0 || index >= _profiles.length) return;
    _profiles.removeAt(index);
    if (_activeProfileIndex == index) {
      _client = null;
      _playlistName = null;
      _activeProfileIndex = null;
    } else if (_activeProfileIndex != null && _activeProfileIndex! > index) {
      _activeProfileIndex = _activeProfileIndex! - 1;
    }
    await _saveProfiles();
    notifyListeners();
  }

  /// Connect to a saved profile by index.
  Future<bool> connectToProfile(int index) async {
    if (index < 0 || index >= _profiles.length) return false;
    final profile = _profiles[index];
    return await login(profile.name, profile.url, profile.mac, profileIndex: index);
  }

  /// Login with credentials. Optionally links to a profile index.
  Future<bool> login(String name, String url, String mac, {int? profileIndex}) async {
    _playlistName = name;
    _client = MacPortalClient(serverUrl: url, macAddress: mac);
    final isSuccess = await _client!.handshake();

    if (isSuccess) {
      _activeProfileIndex = profileIndex;

      // If this was a new login (not from existing profile), save it
      if (profileIndex == null) {
        final newProfile = SavedProfile(name: name, url: url, mac: mac);
        _profiles.add(newProfile);
        _activeProfileIndex = _profiles.length - 1;
        await _saveProfiles();
      }

      notifyListeners();
      return true;
    } else {
      _client = null;
      _playlistName = null;
      return false;
    }
  }

  /// Disconnect but keep profiles.
  Future<void> logout() async {
    _client = null;
    _playlistName = null;
    _activeProfileIndex = null;
    notifyListeners();
  }

  // --- Player Settings ---

  Future<void> setPreferredPlayer(PreferredPlayer player) async {
    _preferredPlayer = player;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlayer, player.name);
    notifyListeners();
  }

  Future<void> setSubtitlesEnabled(bool enabled) async {
    _subtitlesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubs, enabled);
    notifyListeners();
  }
}
