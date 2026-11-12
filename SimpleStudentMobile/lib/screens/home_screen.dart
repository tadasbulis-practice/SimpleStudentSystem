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
    final newUrl = await showDialog<String>(
      context: context,
      builder: (_) => _ApiAddressDialog(initialValue: widget.config.baseUrl),
    );
    if (newUrl == null) return;
    if (newUrl == _ApiAddressDialog.resetValue) {
      await widget.config.resetToDefault();
    } else {
      await widget.config.setBaseUrl(newUrl);
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
                        'The same REST API (contract: swagger.json) is used by a .NET '
                        'web frontend, a PHP frontend and this mobile app on Android '
                        'and iOS phones and tablets.',
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
                        subtitle: '.NET Razor Pages (:6011), PHP (:6021)',
                      ),
                      const _ArchitectureRow(
                        icon: Icons.api,
                        title: 'REST API',
                        subtitle: '.NET 8 Minimal API (:6001) or PHP API (:6002)',
                      ),
                      const _ArchitectureRow(
                        icon: Icons.storage,
                        title: 'Database',
                        subtitle: 'SQL Server (Docker) or MySQL (XAMPP)',
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
                      Text('Which address to use?', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Android emulator:  http://10.0.2.2:6001'),
                      Text('iOS Simulator:  http://localhost:6001'),
                      Text('Real phone / tablet:  http://<PC IP in the same Wi-Fi>:6001'),
                      SizedBox(height: 8),
                      Text('PHP API instead of .NET: use port 6002.'),
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
        if (i.timestampUtc != null) Text('Server time (UTC): ${i.timestampUtc!.toIso8601String()}'),
        if (i.endpoints.isNotEmpty) Text('Endpoints: ${i.endpoints.join(', ')}'),
      ],
    );
  }
}

/// Dialog for changing the API address. Returns the new address,
/// [resetValue] for "default", or null when cancelled.
class _ApiAddressDialog extends StatefulWidget {
  const _ApiAddressDialog({required this.initialValue});

  final String initialValue;
  static const resetValue = '__reset__';

  @override
  State<_ApiAddressDialog> createState() => _ApiAddressDialogState();
}

class _ApiAddressDialogState extends State<_ApiAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API address'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://192.168.1.20:6001',
              ),
              validator: ApiConfig.validate,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Text(
              'Default on this device: ${ApiConfig.defaultBaseUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ApiAddressDialog.resetValue),
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
