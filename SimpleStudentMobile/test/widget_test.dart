import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:simple_student_mobile/config/api_config.dart';
import 'package:simple_student_mobile/main.dart';
import 'package:simple_student_mobile/models/student.dart';
import 'package:simple_student_mobile/services/student_api.dart';

/// Fake API: answers like SimpleStudentApi, without a network.
MockClient fakeApi() {
  final students = [
    {
      'id': 1,
      'firstName': 'Jonas',
      'lastName': 'Jonaitis',
      'email': 'jonas@university.lt',
      'studyProgram': 'Computer Science',
      'enrollmentYear': 2024,
    },
    {
      'id': 2,
      'firstName': 'Ona',
      'lastName': 'Onaite',
      'email': 'ona@university.lt',
      'studyProgram': 'Software Engineering',
      'enrollmentYear': 2025,
    },
  ];

  return MockClient((request) async {
    const headers = {'content-type': 'application/json; charset=utf-8'};
    switch ((request.method, request.url.path)) {
      case ('GET', '/api/info'):
        return http.Response(
          jsonEncode({
            'service': 'SimpleStudentApi',
            'version': '1.2',
            'status': 'ok',
            'message': 'Student CRUD API with SQL Server',
            'environment': 'Test',
            'endpoints': ['/api/students'],
            'timestampUtc': '2026-10-23T08:00:00Z',
          }),
          200,
          headers: headers,
        );
      case ('GET', '/api/students'):
        return http.Response(jsonEncode(students), 200, headers: headers);
      case ('POST', '/api/students'):
        return http.Response(
          jsonEncode({
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'email': ['A valid email is required.'],
            },
          }),
          400,
          headers: headers,
        );
      default:
        return http.Response('', 404);
    }
  });
}

void main() {
  group('Student model', () {
    test('reads and writes the JSON of the API', () {
      final student = Student.fromJson({
        'id': 7,
        'firstName': 'Jonas',
        'lastName': 'Jonaitis',
        'email': 'jonas@university.lt',
        'studyProgram': 'Computer Science',
        'enrollmentYear': 2024,
      });

      expect(student.id, 7);
      expect(student.fullName, 'Jonas Jonaitis');
      expect(student.initials, 'JJ');
      expect(student.toJson()['enrollmentYear'], 2024);
    });
  });

  group('StudentApi', () {
    test('GET /api/students returns the list', () async {
      final api = StudentApi(baseUrl: 'http://test/', client: fakeApi());
      final students = await api.getStudents();
      expect(students.map((s) => s.lastName), ['Jonaitis', 'Onaite']);
    });

    test('400 ValidationProblem becomes field errors', () async {
      final api = StudentApi(baseUrl: 'http://test', client: fakeApi());
      const invalid = Student(
        firstName: 'A',
        lastName: 'B',
        email: 'wrong',
        studyProgram: 'CS',
        enrollmentYear: 2024,
      );

      await expectLater(
        api.createStudent(invalid),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.fieldErrors['email'], 'email error', 'A valid email is required.'),
        ),
      );
    });
  });

  testWidgets('Home tab shows project info, Students tab shows the list', (tester) async {
    // Phone-sized screen → bottom NavigationBar.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SimpleStudentApp(
      config: ApiConfig(initialBaseUrl: 'http://test'),
      httpClient: fakeApi(),
    ));
    await tester.pumpAndSettle();

    // Home tab
    expect(find.text('Heterogeneous system'), findsOneWidget);
    expect(find.text('SimpleStudentApi v1.2 – ok'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Students tab
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.text('Students (2)'), findsOneWidget);
    expect(find.text('Jonas Jonaitis'), findsOneWidget);
    expect(find.text('Ona Onaite'), findsOneWidget);
  });

  testWidgets('Tablet-sized screen uses a NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(2048, 1536);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(SimpleStudentApp(
      config: ApiConfig(initialBaseUrl: 'http://test'),
      httpClient: fakeApi(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
