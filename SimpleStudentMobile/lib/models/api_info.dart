/// Response of `GET /api/info` (`InfoResponse` in swagger.json).
class ApiInfo {
  const ApiInfo({
    required this.service,
    required this.version,
    required this.status,
    required this.message,
    required this.environment,
    required this.endpoints,
    this.timestampUtc,
    this.readOnly,
  });

  final String service;
  final String version;
  final String status;
  final String message;
  final String environment;
  final List<String> endpoints;
  final DateTime? timestampUtc;

  /// Only the Supabase Edge Function API sends it: true in Production (POST / PUT / DELETE → 403).
  final bool? readOnly;

  factory ApiInfo.fromJson(Map<String, dynamic> json) {
    final rawEndpoints = json['endpoints'];
    return ApiInfo(
      service: json['service'] as String? ?? '',
      version: json['version'] as String? ?? '',
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      environment: json['environment'] as String? ?? '',
      endpoints: rawEndpoints is List
          ? rawEndpoints.map((e) => e.toString()).toList()
          : const <String>[],
      timestampUtc: DateTime.tryParse(json['timestampUtc'] as String? ?? ''),
      readOnly: json['readOnly'] as bool?,
    );
  }
}
