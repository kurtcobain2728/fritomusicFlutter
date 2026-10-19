import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../network/innertube/innertube_client.dart';

class YouTubeLoginManager extends ChangeNotifier {
  static final YouTubeLoginManager instance = YouTubeLoginManager._internal();
  factory YouTubeLoginManager() => instance;
  YouTubeLoginManager._internal() {
    loadLogin();
  }

  static const String _keyCookie = AppConstants.prefsYouTubeCookie;
  static const String _keyVisitorData = AppConstants.prefsYouTubeVisitorData;
  static const String _keyDataSyncId = AppConstants.prefsYouTubeDataSyncId;
  static const String _keyAccountName = AppConstants.prefsYouTubeAccountName;
  static const String _keyAccountEmail = AppConstants.prefsYouTubeAccountEmail;
  static const String _keyAccountHandle = AppConstants.prefsYouTubeAccountHandle;
  static const String _keyAccountAvatar = AppConstants.prefsYouTubeAccountAvatar;

  String _cookie = '';
  String _visitorData = '';
  String _dataSyncId = '';
  String _accountName = '';
  String _accountEmail = '';
  String _accountHandle = '';
  String _accountAvatar = '';
  bool _isLoggedIn = false;

  String get cookie => _cookie;
  String get visitorData => _visitorData;
  String get dataSyncId => _dataSyncId;
  String get accountName => _accountName;
  String get accountEmail => _accountEmail;
  String get accountHandle => _accountHandle;
  String get accountAvatar => _accountAvatar;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> loadLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString(_keyCookie) ?? '';
    _visitorData = prefs.getString(_keyVisitorData) ?? '';
    _dataSyncId = prefs.getString(_keyDataSyncId) ?? '';
    _accountName = prefs.getString(_keyAccountName) ?? '';
    _accountEmail = prefs.getString(_keyAccountEmail) ?? '';
    _accountHandle = prefs.getString(_keyAccountHandle) ?? '';
    _accountAvatar = prefs.getString(_keyAccountAvatar) ?? '';
    _isLoggedIn = _cookie.isNotEmpty;

    // Sincronizar cliente InnerTube
    final client = InnerTubeClient.instance;
    client.cookie = _cookie.isNotEmpty ? _cookie : null;
    client.visitorData = _visitorData.isNotEmpty ? _visitorData : null;
    client.dataSyncId = _dataSyncId.isNotEmpty ? _dataSyncId : null;

    notifyListeners();
  }

  Future<void> saveLogin({
    required String cookie,
    required String visitorData,
    required String dataSyncId,
  }) async {
    _cookie = cookie;
    _visitorData = visitorData;
    _dataSyncId = dataSyncId;
    _isLoggedIn = true;

    final client = InnerTubeClient.instance;
    client.cookie = cookie;
    client.visitorData = visitorData;
    client.dataSyncId = dataSyncId;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCookie, cookie);
    await prefs.setString(_keyVisitorData, visitorData);
    await prefs.setString(_keyDataSyncId, dataSyncId);
  }

  Future<void> saveAccountInfo({
    required String name,
    required String email,
    required String handle,
    String avatarUrl = '',
  }) async {
    _accountName = name;
    _accountEmail = email;
    _accountHandle = handle;
    _accountAvatar = avatarUrl;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccountName, name);
    await prefs.setString(_keyAccountEmail, email);
    await prefs.setString(_keyAccountHandle, handle);
    await prefs.setString(_keyAccountAvatar, avatarUrl);
  }

  Future<void> fetchAccountInfo() async {
    if (!_isLoggedIn) return;
    try {
      final info = await InnerTubeClient.instance.getAccountInfo();
      if (info != null && (info['name']?.isNotEmpty == true || info['avatar']?.isNotEmpty == true)) {
        await saveAccountInfo(
          name: info['name'] ?? _accountName,
          email: info['email'] ?? _accountEmail,
          handle: info['handle'] ?? _accountHandle,
          avatarUrl: info['avatar'] ?? _accountAvatar,
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    _cookie = '';
    _visitorData = '';
    _dataSyncId = '';
    _accountName = '';
    _accountEmail = '';
    _accountHandle = '';
    _accountAvatar = '';
    _isLoggedIn = false;

    final client = InnerTubeClient.instance;
    client.cookie = null;
    client.visitorData = null;
    client.dataSyncId = null;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCookie);
    await prefs.remove(_keyVisitorData);
    await prefs.remove(_keyDataSyncId);
    await prefs.remove(_keyAccountName);
    await prefs.remove(_keyAccountEmail);
    await prefs.remove(_keyAccountHandle);
    await prefs.remove(_keyAccountAvatar);
  }
}
