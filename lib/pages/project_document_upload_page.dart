import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/models/dashboard_overview.dart';
import '../core/services/api_exception.dart';
import '../core/repositories/project_update_repository.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/local_database.dart';
import '../core/services/session_provider.dart';

class ProjectDocumentUploadPage extends StatefulWidget {
  const ProjectDocumentUploadPage({required this.projects, super.key});

  final List<AssignedProject> projects;

  @override
  State<ProjectDocumentUploadPage> createState() =>
      _ProjectDocumentUploadPageState();
}

class _ProjectDocumentUploadPageState extends State<ProjectDocumentUploadPage> {
  static const _dashboardService = DashboardService();
  static const _inputRadius = 12.0;
  static const _maxFileBytes = 5120 * 1024;

  final _repository = ProjectUpdateRepository();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  AssignedProject? _selectedProject;
  XFile? _selectedFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.projects.isNotEmpty) {
      _selectedProject = widget.projects.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFile(type: FileType.any);
      if (!mounted || result == null) return;

      final path = result.path;
      if (path == null) {
        _showMessage('Unable to access the selected file.');
        return;
      }
      setState(() => _selectedFile = XFile(path));
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(error.message ?? 'Unable to open the file picker.');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final project = _selectedProject;
    final file = _selectedFile;
    if (project == null || file == null) {
      _showMessage('Select a project and file before uploading.');
      return;
    }

    final token = context.read<SessionProvider>().token;
    if (token == null) {
      _showMessage('You are not signed in. Please log in again.');
      return;
    }

    setState(() => _isSubmitting = true);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    late final String localId;
    late final String storedPath;
    try {
      final fileSize = await File(file.path).length();
      if (fileSize > _maxFileBytes) {
        _showMessage('The selected file must be 5 MB or smaller.');
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
      storedPath = await _copyToAppStorage(file);
      final localRecord = await _repository.writeProjectUpdate(
        projectId: project.id,
        name: name,
        description: description,
        filePath: storedPath,
        fileName: file.name,
      );
      localId = localRecord.localId;
    } on LocalDatabaseException catch (error) {
      if (mounted) {
        _showMessage('Unable to store this update locally. (${error.message})');
        setState(() => _isSubmitting = false);
      }
      return;
    } on Object catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to store this update locally right now. Please try again.',
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }

    try {
      await _repository.recordProjectUpdateSyncAttempt(localId);
      await _dashboardService.uploadProjectDocument(
        token: token,
        projectId: project.id,
        file: XFile(storedPath),
        name: name,
        description: description,
      );
      await _repository.markProjectUpdateSynced(localId);
      if (mounted) context.pop(true);
    } on Object catch (error) {
      final message = error is ApiException
          ? error.message
          : 'Unable to upload the document right now. Please try again.';
      try {
        await _repository.recordProjectUpdateSyncFailure(localId, message);
      } on Object catch (_) {}
      if (mounted) {
        _showMessage(
          '$message The update is saved locally and queued for sync.',
        );
        context.pop(false);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String> _copyToAppStorage(XFile file) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'project_updates'));
    await directory.create(recursive: true);
    final target = p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.path)}',
    );
    await File(file.path).copy(target);
    return target;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('New Update')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<AssignedProject>(
                initialValue: _selectedProject,
                isExpanded: true,
                decoration: _inputDecoration(colorScheme, labelText: 'Project'),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project,
                        child: Text(
                          project.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (project) => setState(() => _selectedProject = project),
                validator: (project) =>
                    project == null ? 'Select a project.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                enabled: !_isSubmitting,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(colorScheme, labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a name for this update.';
                  }
                  if (value.trim().length > 255) {
                    return 'Name must be 255 characters or fewer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                maxLength: 500,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  colorScheme,
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a description.';
                  }
                  if (value.trim().length > 500) {
                    return 'Description must be 500 characters or fewer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _selectedFile == null
                      ? 'Choose document or media'
                      : 'Change file',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_inputRadius),
                  ),
                ),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 8),
                Text(
                  _selectedFile!.name,
                  style: TextStyle(color: colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Maximum file size: 5 MB',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_inputRadius),
                    ),
                  ),
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSecondary,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isSubmitting ? 'Uploading…' : 'Upload update',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme colorScheme, {
    required String labelText,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_inputRadius),
        borderSide: BorderSide(color: colorScheme.secondary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
