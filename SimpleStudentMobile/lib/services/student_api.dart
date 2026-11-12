import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_info.dart';
import '../models/student.dart';

/// Thin client for SimpleStudentApi (.NET) or SimpleStudentPhpApi (PHP) –
/// both implement the same contract (swagger.json):
///
/// | Method                 | HTTP                        | operationId    |
/// |------------------------|-----------------------------|----------------|
/// | [getInfo]              | GET    /api/info            | GetInfo        |
/// | [getStudents]          | GET    /api/students        | GetStudents    |
/// | [getStudent]           | GET    /api/students/{id}   | GetStudent     |
/// | [createStudent]        | POST   /api/students        | CreateStudent  |
/// | [updateStudent]        | PUT    /api/students/{id}   | UpdateStudent  |
/// | [deleteStudent]        | DELETE /api/students/{id}   | DeleteStudent  |
class StudentApi {
  StudentApi({required String baseUrl, http.Client? client})
      : baseUrl = _trimSlash(baseUrl),
        _client = client ?? http.Client();

  /// e.g. `http://10.0.2.2:6001` (Android emulator → your computer).
  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);
  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Info ──────────────────────────────────────────────────────────────────

  Future<ApiInfo> getInfo() async {
    final response = await _send(() => _client.get(_uri('/api/info')));
    return ApiInfo.fromJson(_decodeObject(response));
  }

  // ── Students CRUD ─────────────────────────────────────────────────────────

  Future<List<Student>> getStudents() async {
    final response = await _send(() => _client.get(_uri('/api/students')));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const ApiException('Unexpected response: a list was expected.');
    }
    return body
        .whereType<Map<String, dynamic>>()
        .map(Student.fromJson)
        .toList();
  }

  Future<Student> getStudent(int id) async {
    final response = await _send(() => _client.get(_uri('/api/students/$id')));
    return Student.fromJson(_decodeObject(response));
  }

  Future<Student> createStudent(Student student) async {
    final response = await _send(() => _client.post(
          _uri('/api/students'),
          headers: _jsonHeaders,
          body: jsonEncode(student.toJson()),
        ));
    return Student.fromJson(_decodeObject(response));
  }

  Future<Student> updateStudent(Student student) async {
    final response = await _send(() => _client.put(
          _uri('/api/students/${student.id}'),
          headers: _jsonHeaders,
          body: jsonEncode(student.toJson()),
        ));
    return Student.fromJson(_decodeObject(response));
  }

  Future<void> deleteStudent(int id) async {
    await _send(() => _client.delete(_uri('/api/students/$id')));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static String _trimSlash(String url) {
    var result = url.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Sends the request and turns every problem into an [ApiException]
  /// with a message that can be shown to the user.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        'The API did not answer within ${_timeout.inSeconds} s.\n'
        'Is it running? Is the address $baseUrl correct?',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Cannot connect to $baseUrl.\n${e.message}',
      );
    } catch (e) {
      // e.g. SocketException, HandshakeException, invalid URL
      throw ApiException('Cannot connect to $baseUrl.\n$e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw ApiException.fromResponse(response);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response: an object was expected.');
    }
    return body;
  }
}

/// Error returned by the API (or a connection problem).
///
/// For HTTP 400 the API returns a *ValidationProblem* (RFC 7807):
/// ```json
/// { "title": "One or more validation errors occurred.",
///   "status": 400,
///   "errors": { "email": ["A valid email is required."] } }
/// ```
/// [fieldErrors] contains the `errors` map so the form can show each message
/// under the right input.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  factory ApiException.fromResponse(http.Response response) {
    final code = response.statusCode;
    final fieldErrors = <String, String>{};
    String? title;

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        title = body['title'] as String?;
        final errors = body['errors'];
        if (errors is Map) {
          errors.forEach((key, value) {
            final text = value is List ? value.join(' ') : value.toString();
            fieldErrors[key.toString()] = text;
          });
        }
      }
    } catch (_) {
      // Body is empty or not JSON – keep the default message below.
    }

    final message = switch (code) {
      400 => title ?? 'The data is not valid.',
      404 => 'Not found (404). The student may have been deleted.',
      _ => title ?? 'The API returned HTTP $code.',
    };
    return ApiException(message, statusCode: code, fieldErrors: fieldErrors);
  }

  @override
  String toString() => message;
}
