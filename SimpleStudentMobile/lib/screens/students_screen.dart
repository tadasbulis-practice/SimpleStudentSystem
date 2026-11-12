import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/student_api.dart';
import '../widgets/centered_content.dart';
import 'student_form_screen.dart';

/// Tab 2 – Student CRUD.
///
/// * **R**ead   – list loads from `GET /api/students`, pull down to refresh
/// * **C**reate – "+" button → form → `POST /api/students`
/// * **U**pdate – tap a student → form → `PUT /api/students/{id}`
/// * **D**elete – swipe left (or the delete button in the form) → `DELETE /api/students/{id}`
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.api});

  final StudentApi api;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<Student> _students = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The API address was changed on the Home tab.
    if (oldWidget.api.baseUrl != widget.api.baseUrl) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await widget.api.getStudents();
      students.sort((a, b) {
        final byLast = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
        return byLast != 0 ? byLast : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
      });
      if (!mounted) return;
      setState(() => _students = students);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Opens the form. `student == null` → create, otherwise → edit.
  Future<void> _openForm([Student? student]) async {
    final result = await Navigator.of(context).push<FormResult>(
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(api: widget.api, student: student),
      ),
    );
    if (result == null || !mounted) return;
    _showMessage(switch (result) {
      FormResult.created => 'Student created.',
      FormResult.updated => 'Student updated.',
      FormResult.deleted => 'Student deleted.',
    });
    await _load();
  }

  Future<bool> _confirmDelete(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text('${student.fullName} will be removed from the database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await widget.api.deleteStudent(student.id);
      if (mounted) _showMessage('${student.fullName} deleted.');
      return true;
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message);
      return false;
    }
  }

  void _removeFromList(Student student) {
    setState(() {
      _students = _students.where((s) => s.id != student.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading || _error != null ? 'Students' : 'Students (${_students.length})'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CenteredContent(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageView(
        icon: Icons.cloud_off,
        title: 'Cannot load students',
        text: _error!,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    if (_students.isEmpty) {
      return const _MessageView(
        icon: Icons.person_search,
        title: 'No students yet',
        text: 'Press "Add" to create the first one.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88), // room for the FAB
      itemCount: _students.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final student = _students[index];
        return Dismissible(
          key: ValueKey(student.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
          ),
          confirmDismiss: (_) => _confirmDelete(student),
          onDismissed: (_) => _removeFromList(student),
          child: ListTile(
            leading: CircleAvatar(child: Text(student.initials)),
            title: Text(student.fullName),
            subtitle: Text('${student.studyProgram} · ${student.enrollmentYear}\n${student.email}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openForm(student),
          ),
        );
      },
    );
  }
}

/// Centered icon + text, used for "error" and "empty" states.
/// Wrapped in a ListView so pull-to-refresh still works.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}
