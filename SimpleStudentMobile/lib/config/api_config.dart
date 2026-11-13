import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The environments the app can talk to.
///
/// | Environment | API                                              | Address                            |
/// |-------------|--------------------------------------------------|------------------------------------|
/// | Dev         | .NET / PHP / Python / Node API in Docker on a PC | platform default, see the table in [ApiConfig] |
/// | Test        | Supabase Edge Function, project "SimpleStudent System Test" | [ApiConfig.testBaseUrl]    |
/// | Production  | Supabase Edge Function, project "SimpleStudentSystem" (read-only) | [ApiConfig.productionBaseUrl] |
/// | Custom      | any address typed in the app (e.g. PC LAN IP)    | saved on the device                |
///
/// Test and Production are deployed by GitHub Actions (release/vX.Y.Z → Test, tag vX.Y.Z → Production),
/// see deploy/SUPABASE.md in the repository.
enum ApiEnvironment {
  dev('Dev', 'Docker on your computer'),
  test('Test', 'Supabase – release candidates'),
  production('Production', 'Supabase – released version, read-only'),
  custom('Custom', 'Any address, e.g. your PC in the same Wi-Fi');

  const ApiEnvironment(this.label, this.description);

  final String label;
  final String description;

  /// "test" → [ApiEnvironment.test]; unknown or empty → null.
  static ApiEnvironment? fromName(String? name) {
    for (final env in values) {
      if (env.name == name?.trim().toLowerCase()) return env;
    }
    if (name?.trim().toLowerCase() == 'prod') return production;
    return null;
  }
}

/// Where the app finds SimpleStudentApi.
///
/// **Dev** – the phone is a *different computer* than the one running Docker, so
/// `localhost` does not always mean "my PC":
///
/// | Where the app runs        | Address of the API on your PC        |
/// |---------------------------|--------------------------------------|
/// | Android emulator          | http://10.0.2.2:6001                 |
/// | iOS Simulator (macOS)     | http://localhost:6001                |
/// | Real phone / tablet (Wi-Fi)| http://<your PC LAN IP>:6001 → use **Custom** |
///
/// **Test / Production** – public HTTPS addresses in Supabase, the same on every device.
///
/// Priority at start: environment saved in the app → `--dart-define=API_ENV=test|production|dev` →
/// `--dart-define=API_BASE_URL=...` (Custom) → Dev.
class ApiConfig extends ChangeNotifier {
  ApiConfig({
    ApiEnvironment? initialEnvironment,
    String? initialBaseUrl,
    SharedPreferences? preferences,
  })  : _environment = initialEnvironment ??
            (initialBaseUrl != null ? ApiEnvironment.custom : defaultEnvironment),
        _customBaseUrl = initialBaseUrl ?? (_fromDartDefine.isNotEmpty ? _fromDartDefine : null),
        _preferences = preferences;

  /// Supabase Edge Function API – Test project ("SimpleStudent System Test").
  static const testBaseUrl =
      'https://xkkzlqedgvztdlvgerbu.supabase.co/functions/v1/simplestudent-api';

  /// Supabase Edge Function API – Production project ("SimpleStudentSystem"). Read-only: POST / PUT / DELETE → 403.
  static const productionBaseUrl =
      'https://ptkcvmldafnczhrixvcf.supabase.co/functions/v1/simplestudent-api';

  /// Swagger UI for Test and Production (GitHub Pages).
  static const swaggerUiUrl = 'https://tadasbulis-practice.github.io/SimpleStudentSystem/';

  static const _prefsEnvironmentKey = 'api_environment';

  /// Kept from the first version of the app: an address saved there is now the Custom address.
  static const _prefsCustomUrlKey = 'api_base_url';

  /// Set at build time, e.g. `flutter run --dart-define=API_ENV=test`
  static const _envFromDartDefine = String.fromEnvironment('API_ENV');

  /// Set at build time, e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:6001`
  static const _fromDartDefine = String.fromEnvironment('API_BASE_URL');

  /// Port of the .NET API in docker-compose.yml (`6001:8080`).
  /// The PHP API uses 6002, Python 6003, Node.js 6004 / 6005.
  static const defaultPort = 6001;

  /// Environment used when nothing is saved in the app.
  static ApiEnvironment get defaultEnvironment {
    final fromDefine = ApiEnvironment.fromName(_envFromDartDefine);
    if (fromDefine != null) return fromDefine;
    if (_fromDartDefine.isNotEmpty) return ApiEnvironment.custom;
    return ApiEnvironment.dev;
  }

  /// Dev address: the API in Docker on the computer that runs the emulator / simulator.
  static String get devBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 is the special alias of the host computer inside the Android emulator.
      return 'http://10.0.2.2:$defaultPort';
    }
    return 'http://localhost:$defaultPort';
  }

  /// Kept for older code and docs: the address of the default environment.
  static String get defaultBaseUrl {
    if (_fromDartDefine.isNotEmpty) return _fromDartDefine;
    return devBaseUrl;
  }

  /// Fixed address of an environment; null for [ApiEnvironment.custom].
  static String? addressOf(ApiEnvironment environment) => switch (environment) {
        ApiEnvironment.dev => devBaseUrl,
        ApiEnvironment.test => testBaseUrl,
        ApiEnvironment.production => productionBaseUrl,
        ApiEnvironment.custom => null,
      };

  /// Reads the saved environment and address (if any) from the device storage.
  static Future<ApiConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsCustomUrlKey);
      final savedEnv = ApiEnvironment.fromName(prefs.getString(_prefsEnvironmentKey));
      return ApiConfig(
        // Older app version saved only an address → it becomes Custom.
        initialEnvironment: savedEnv ?? (savedUrl != null ? ApiEnvironment.custom : null),
        initialBaseUrl: savedUrl,
        preferences: prefs,
      );
    } catch (_) {
      // Storage not available – the app still works with the default environment.
      return ApiConfig();
    }
  }

  ApiEnvironment _environment;
  String? _customBaseUrl;
  final SharedPreferences? _preferences;

  /// The selected environment.
  ApiEnvironment get environment => _environment;

  /// The address typed for [ApiEnvironment.custom] (kept while another environment is selected).
  String get customBaseUrl => _customBaseUrl ?? devBaseUrl;

  /// The address the app uses now.
  String get baseUrl => addressOf(_environment) ?? customBaseUrl;

  /// Production API refuses writes (API_READ_ONLY=true) – the UI can warn before the user tries.
  bool get isReadOnlyEnvironment => _environment == ApiEnvironment.production;

  /// Switches to Dev, Test or Production (or Custom with the last custom address).
  Future<void> setEnvironment(ApiEnvironment environment) async {
    if (environment == _environment) return;
    _environment = environment;
    notifyListeners();
    await _preferences?.setString(_prefsEnvironmentKey, environment.name);
  }

  /// Saves a custom address and switches to [ApiEnvironment.custom].
  Future<void> setCustomBaseUrl(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    if (cleaned == _customBaseUrl && _environment == ApiEnvironment.custom) return;
    _customBaseUrl = cleaned;
    _environment = ApiEnvironment.custom;
    notifyListeners();
    await _preferences?.setString(_prefsCustomUrlKey, cleaned);
    await _preferences?.setString(_prefsEnvironmentKey, ApiEnvironment.custom.name);
  }

  /// Same as [setCustomBaseUrl] – name kept from the first version of the app.
  Future<void> setBaseUrl(String value) => setCustomBaseUrl(value);

  /// Back to the default environment (Dev, or what `--dart-define` says); forgets the saved choice.
  Future<void> resetToDefault() async {
    _environment = defaultEnvironment;
    _customBaseUrl = _fromDartDefine.isNotEmpty ? _fromDartDefine : null;
    notifyListeners();
    await _preferences?.remove(_prefsEnvironmentKey);
    await _preferences?.remove(_prefsCustomUrlKey);
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
