import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/student.dart';
import '../services/student_api.dart';
import '../widgets/centered_content.dart';

/// What happened in the form – shown as a SnackBar on the list.
enum FormResult { created, updated, deleted }

/// Create (student == null) or edit/delete an existing student.
///
/// Validation happens twice, like in the web frontends:
/// 1. in the app (fast feedback, same rules as the API),
/// 2. in the API – a 400 ValidationProblem is shown under the right field.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, required this.api, this.student});

  final StudentApi api;
  final Student? student;

  bool get isEdit => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _firstName = TextEditingController(text: widget.student?.firstName);
  late final _lastName = TextEditingController(text: widget.student?.lastName);
  late final _email = TextEditingController(text: widget.student?.email);
  late final _studyProgram = TextEditingController(text: widget.student?.studyProgram);
  late final _enrollmentYear = TextEditingController(
    text: (widget.student?.enrollmentYear ?? DateTime.now().year).toString(),
  );

  bool _saving = false;
  String? _generalError;

  /// Field errors returned by the API (keys = JSON field names).
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _studyProgram, _enrollmentYear]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validation (same rules as StudentValidator in the API) ─────────────────

  String? _required(String? value, String field, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return _serverErrors[field];
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || !text.contains('@')) return 'A valid email is required.';
    return _serverErrors['email'];
  }

  String? _validateYear(String? value) {
    final year = int.tryParse(value?.trim() ?? '');
    if (year == null || year < 2000 || year > 2100) {
      return 'Enrollment year must be between 2000 and 2100.';
    }
    return _serverErrors['enrollmentYear'];
  }

  /// Typing in a field removes the old server error of that field.
  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = Map.of(_serverErrors)..remove(field));
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _serverErrors = const {};
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final student = Student(
      id: widget.student?.id ?? 0,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      studyProgram: _studyProgram.text.trim(),
      enrollmentYear: int.parse(_enrollmentYear.text.trim()),
    );

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await widget.api.updateStudent(student);
      } else {
        await widget.api.createStudent(student);
      }
      if (!mounted) return;
      Navigator.of(context).pop(widget.isEdit ? FormResult.updated : FormResult.created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _generalError = e.message;
      });
      // Show the API's field errors under the inputs.
      _formKey.currentState!.validate();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final student = widget.student!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text('${student.fullName} will be removed from the database.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.api.deleteStudent(student.id);
      if (!mounted) return;
      Navigator.of(context).pop(FormResult.deleted);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generalError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit student #${widget.student!.id}' : 'New student'),
        actions: [
          if (widget.isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 600,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            // SingleChildScrollView (not ListView) so that every field is
            // always built and validate() checks all of them.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_generalError != null) ...[
                    Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_generalError!, style: TextStyle(color: colors.onErrorContainer)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    validator: (v) => _required(v, 'firstName', 'First name'),
                    onChanged: (_) => _clearServerError('firstName'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    validator: (v) => _required(v, 'lastName', 'Last name'),
                    onChanged: (_) => _clearServerError('lastName'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    maxLength: 200,
                    validator: _validateEmail,
                    onChanged: (_) => _clearServerError('email'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _studyProgram,
                    decoration: const InputDecoration(
                      labelText: 'Study program',
                      hintText: 'e.g. Computer Science',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    validator: (v) => _required(v, 'studyProgram', 'Study program'),
                    onChanged: (_) => _clearServerError('studyProgram'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _enrollmentYear,
                    decoration: const InputDecoration(labelText: 'Enrollment year', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    textInputAction: TextInputAction.done,
                    validator: _validateYear,
                    onChanged: (_) => _clearServerError('enrollmentYear'),
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(widget.isEdit ? 'Save changes' : 'Create student'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
