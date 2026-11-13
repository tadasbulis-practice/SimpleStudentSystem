import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/api_info.dart';
import '../services/student_api.dart';
import '../widgets/centered_content.dart';

/// Tab 1 – general information about the project + API connection check.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.config,
    required this.api,
    required this.onOpenStudents,
  });

  final ApiConfig config;
  final StudentApi api;
  final VoidCallback onOpenStudents;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ApiInfo? _info;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api.baseUrl != widget.api.baseUrl) _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final info = await widget.api.getInfo();
      if (!mounted) return;
      setState(() => _info = info);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _editApiAddress() async {
    final choice = await showDialog<ApiChoice>(
      context: context,
      builder: (_) => ApiEnvironmentDialog(
        initialEnvironment: widget.config.environment,
        initialCustomUrl: widget.config.customBaseUrl,
      ),
    );
    if (choice == null) return;
    if (choice.reset) {
      await widget.config.resetToDefault();
    } else if (choice.environment == ApiEnvironment.custom) {
      await widget.config.setCustomBaseUrl(choice.customUrl!);
    } else {
      await widget.config.setEnvironment(choice.environment);
    }
    // The new address arrives through didUpdateWidget → _checkConnection().
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Student'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: EnvironmentChip(environment: widget.config.environment, onTap: _editApiAddress),
          ),
          IconButton(
            tooltip: 'API address',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: _editApiAddress,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkConnection,
        child: CenteredContent(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // ── About the project ────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hub_outlined, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Heterogeneous system', style: textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This Flutter app is one more client of SimpleStudentApi. '
                        'The same REST API (contract: swagger.json) is used by .NET, '
                        'Blazor and PHP web frontends and this mobile app on Android '
                        'and iOS phones and tablets – on your computer (Dev) or in the '
                        'cloud (Test, Production).',
                      ),
                      const SizedBox(height: 16),
                      const _ArchitectureRow(
                        icon: Icons.phone_iphone,
                        title: 'Mobile client',
                        subtitle: 'Flutter / Dart – this app',
                      ),
                      const _ArchitectureRow(
                        icon: Icons.web,
                        title: 'Web clients',
                        subtitle: '.NET Razor Pages, Blazor Server / WebAssembly, PHP',
                      ),
                      const _ArchitectureRow(
                        icon: Icons.api,
                        title: 'REST API',
                        subtitle: 'Dev: .NET, PHP, Python, Node.js in Docker\n'
                            'Test / Production: Supabase Edge Function (Node.js + Express)',
                      ),
                      const _ArchitectureRow(
                        icon: Icons.storage,
                        title: 'Database',
                        subtitle: 'Dev: SQL Server, PostgreSQL (Docker), MySQL (XAMPP)\n'
                            'Test / Production: Supabase PostgreSQL',
                        isLast: true,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: widget.onOpenStudents,
                        icon: const Icon(Icons.people),
                        label: const Text('Open students'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── API connection ───────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('API connection', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          EnvironmentChip(environment: widget.config.environment),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.config.environment.description,
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              widget.api.baseUrl,
                              style: textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                          TextButton(
                            onPressed: _editApiAddress,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ConnectionStatus(checking: _checking, info: _info, error: _error),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _checking ? null : _checkConnection,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Test connection'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Help ─────────────────────────────────────────────────────
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Which environment to use?', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Dev – the API in Docker on your computer:'),
                      Text('    Android emulator:  http://10.0.2.2:6001'),
                      Text('    iOS Simulator:  http://localhost:6001'),
                      Text('    PHP API: port 6002, Python 6003, Node.js 6004 / 6005'),
                      SizedBox(height: 8),
                      Text('Test – Supabase in the cloud, works on every device. Writing allowed.'),
                      Text('Production – Supabase, released version. Read-only: adding, editing '
                          'and deleting answer 403.'),
                      SizedBox(height: 8),
                      Text('Custom – any address, e.g. a real phone in the same Wi-Fi: '
                          'http://<PC IP>:6001'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchitectureRow extends StatelessWidget {
  const _ArchitectureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.arrow_downward, size: 18, color: colors.outline),
            ),
          ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.checking, this.info, this.error});

  final bool checking;
  final ApiInfo? info;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (checking) {
      return const Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Checking GET /api/info …'),
        ],
      );
    }

    if (error != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(error!, style: TextStyle(color: colors.error))),
        ],
      );
    }

    final i = info;
    if (i == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Text('${i.service} v${i.version} – ${i.status}')),
          ],
        ),
        const SizedBox(height: 4),
        Text(i.message),
        Text('Environment: ${i.environment}'),
        if (i.readOnly == true)
          Text(
            'Read-only: adding, editing and deleting are disabled here.',
            style: TextStyle(color: colors.error),
          ),
        if (i.timestampUtc != null) Text('Server time (UTC): ${i.timestampUtc!.toIso8601String()}'),
        if (i.endpoints.isNotEmpty) Text('Endpoints: ${i.endpoints.join(', ')}'),
      ],
    );
  }
}

/// Result of [ApiEnvironmentDialog].
class ApiChoice {
  const ApiChoice(this.environment, {this.customUrl, this.reset = false});

  /// "Use default" – forget the saved choice.
  const ApiChoice.reset() : this(ApiEnvironment.dev, reset: true);

  final ApiEnvironment environment;

  /// Only for [ApiEnvironment.custom].
  final String? customUrl;
  final bool reset;
}

/// Small coloured label of the environment: DEV, TEST, PROD, CUSTOM.
class EnvironmentChip extends StatelessWidget {
  const EnvironmentChip({super.key, required this.environment, this.onTap});

  final ApiEnvironment environment;
  final VoidCallback? onTap;

  static const _colors = {
    ApiEnvironment.dev: Colors.blueGrey,
    ApiEnvironment.test: Colors.orange,
    ApiEnvironment.production: Colors.red,
    ApiEnvironment.custom: Colors.purple,
  };

  static const _short = {
    ApiEnvironment.dev: 'DEV',
    ApiEnvironment.test: 'TEST',
    ApiEnvironment.production: 'PROD',
    ApiEnvironment.custom: 'CUSTOM',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[environment]!;
    return Material(
      color: color.withValues(alpha: 0.15),
      shape: StadiumBorder(side: BorderSide(color: color)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            _short[environment]!,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/// Dialog for choosing the API environment: Dev, Test, Production or a Custom address.
/// Returns an [ApiChoice], or null when cancelled.
class ApiEnvironmentDialog extends StatefulWidget {
  const ApiEnvironmentDialog({
    super.key,
    required this.initialEnvironment,
    required this.initialCustomUrl,
  });

  final ApiEnvironment initialEnvironment;
  final String initialCustomUrl;

  @override
  State<ApiEnvironmentDialog> createState() => _ApiEnvironmentDialogState();
}

class _ApiEnvironmentDialogState extends State<ApiEnvironmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late ApiEnvironment _selected = widget.initialEnvironment;
  late final _controller = TextEditingController(text: widget.initialCustomUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_selected == ApiEnvironment.custom) {
      if (!_formKey.currentState!.validate()) return;
      Navigator.of(context).pop(ApiChoice(_selected, customUrl: _controller.text.trim()));
    } else {
      Navigator.of(context).pop(ApiChoice(_selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('API environment'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final env in ApiEnvironment.values)
                ListTile(
                  key: ValueKey('env-${env.name}'),
                  dense: true,
                  selected: env == _selected,
                  leading: Icon(
                    env == _selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: env == _selected ? colors.primary : null,
                  ),
                  title: Row(
                    children: [
                      Text(env.label),
                      const SizedBox(width: 8),
                      EnvironmentChip(environment: env),
                    ],
                  ),
                  subtitle: Text(
                    ApiConfig.addressOf(env) ?? env.description,
                    style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  onTap: () => setState(() => _selected = env),
                ),
              if (_selected == ApiEnvironment.custom)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFormField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Custom base URL',
                      hintText: 'http://192.168.1.20:6001',
                    ),
                    validator: ApiConfig.validate,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
              if (_selected == ApiEnvironment.production)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Production is read-only: the list works, adding, editing and deleting answer 403.',
                    style: textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const ApiChoice.reset()),
          child: const Text('Use default'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
