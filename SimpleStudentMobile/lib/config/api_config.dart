import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app finds SimpleStudentApi.
///
/// The phone is a *different computer* than the one running Docker, so
/// `localhost` does not always mean "my PC":
///
/// | Where the app runs        | Address of the API on your PC        |
/// |---------------------------|--------------------------------------|
/// | Android emulator          | http://10.0.2.2:6001                 |
/// | iOS Simulator (macOS)     | http://localhost:6001                |
/// | Real phone / tablet (Wi-Fi)| http://<your PC LAN IP>:6001        |
///
/// Priority: value saved in the app → `--dart-define=API_BASE_URL=...` →
/// platform default from the table above.
class ApiConfig extends ChangeNotifier {
  ApiConfig({String? initialBaseUrl, SharedPreferences? preferences})
      : _baseUrl = initialBaseUrl ?? defaultBaseUrl,
        _preferences = preferences;

  static const _prefsKey = 'api_base_url';

  /// Set at build time, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:6001`
  static const _fromDartDefine = String.fromEnvironment('API_BASE_URL');

  /// Port of the .NET API in docker-compose.yml (`6001:8080`).
  /// The PHP API uses 6002.
  static const defaultPort = 6001;

  static String get defaultBaseUrl {
    if (_fromDartDefine.isNotEmpty) return _fromDartDefine;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 is the special alias of the host computer inside the Android emulator.
      return 'http://10.0.2.2:$defaultPort';
    }
    return 'http://localhost:$defaultPort';
  }

  /// Reads the saved address (if any) from the device storage.
  static Future<ApiConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ApiConfig(
        initialBaseUrl: prefs.getString(_prefsKey),
        preferences: prefs,
      );
    } catch (_) {
      // Storage not available – the app still works with the default address.
      return ApiConfig();
    }
  }

  String _baseUrl;
  final SharedPreferences? _preferences;

  String get baseUrl => _baseUrl;

  Future<void> setBaseUrl(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == _baseUrl) return;
    _baseUrl = cleaned;
    notifyListeners();
    await _preferences?.setString(_prefsKey, cleaned);
  }

  Future<void> resetToDefault() async {
    _baseUrl = defaultBaseUrl;
    notifyListeners();
    await _preferences?.remove(_prefsKey);
  }

  /// Simple check used by the settings dialog.
  static String? validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the API address.';
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Use a full address, e.g. http://192.168.1.20:6001';
    }
    return null;
  }
}
