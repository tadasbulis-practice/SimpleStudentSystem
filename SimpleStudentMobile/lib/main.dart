import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'screens/home_screen.dart';
import 'screens/students_screen.dart';
import 'services/student_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await ApiConfig.load();
  runApp(SimpleStudentApp(config: config));
}

class SimpleStudentApp extends StatelessWidget {
  const SimpleStudentApp({super.key, required this.config, this.httpClient});

  final ApiConfig config;

  /// Only tests pass a client (a MockClient); the app uses the default one.
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Student',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5AA8)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5AA8),
          brightness: Brightness.dark,
        ),
      ),
      home: AppShell(config: config, httpClient: httpClient),
    );
  }
}

/// The tab menu: **Home** and **Students**.
///
/// * phone (narrow screen)  → [NavigationBar] at the bottom
/// * tablet / landscape     → [NavigationRail] on the left
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.config, this.httpClient});

  final ApiConfig config;
  final http.Client? httpClient;

  /// Screens wider than this get the side rail instead of the bottom bar.
  static const tabletBreakpoint = 600.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedTab = 0;

  /// One HTTP client for the whole app (reuses connections).
  late final http.Client _client = widget.httpClient ?? http.Client();

  @override
  void dispose() {
    if (widget.httpClient == null) _client.close();
    super.dispose();
  }

  static const _tabs = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Students'),
  ];

  void _selectTab(int index) => setState(() => _selectedTab = index);

  @override
  Widget build(BuildContext context) {
    // Rebuild when the API address changes in the settings dialog.
    return ListenableBuilder(
      listenable: widget.config,
      builder: (context, _) {
        final api = StudentApi(
          baseUrl: widget.config.baseUrl,
          client: _client,
        );

        // IndexedStack keeps both tabs alive, so the student list is not
        // reloaded every time you switch tabs.
        final body = IndexedStack(
          index: _selectedTab,
          children: [
            HomeScreen(
              config: widget.config,
              api: api,
              onOpenStudents: () => _selectTab(1),
            ),
            StudentsScreen(api: api),
          ],
        );

        final isWide = MediaQuery.sizeOf(context).width >= AppShell.tabletBreakpoint;

        if (isWide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedTab,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(Icons.school, size: 32),
                    ),
                    destinations: [
                      for (final tab in _tabs)
                        NavigationRailDestination(
                          icon: Icon(tab.icon),
                          selectedIcon: Icon(tab.selectedIcon),
                          label: Text(tab.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: _selectTab,
            destinations: [
              for (final tab in _tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
