import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/services/api_exception.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/session_provider.dart';

class CreateKpiArgs {
  const CreateKpiArgs({required this.projectId, required this.projectTitle});

  final String projectId;
  final String projectTitle;
}

class CreateKpiScreen extends StatefulWidget {
  const CreateKpiScreen({required this.args, super.key});

  final CreateKpiArgs args;

  @override
  State<CreateKpiScreen> createState() => _CreateKpiScreenState();
}

class _CreateKpiScreenState extends State<CreateKpiScreen> {
  static const _dashboardService = DashboardService();
  static const _inputRadius = 12.0;
  static const _aggregationMethods = [
    'Sum',
    'Average',
    'Latest',
    'Minimum',
    'Maximum',
    'Count',
  ];
  static const _reportingPeriods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Annually',
  ];

  final _formKey = GlobalKey<FormState>();
  final _objectiveIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _baselineController = TextEditingController();
  final _targetController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _aggregationMethod = _aggregationMethods.first;
  String _reportingPeriod = _reportingPeriods.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _objectiveIdController.dispose();
    _nameController.dispose();
    _baselineController.dispose();
    _targetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static num? _parseNumber(String value) {
    final text = value.trim();
    return int.tryParse(text) ?? double.tryParse(text);
  }

  String? _validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    if (_parseNumber(value) == null) {
      return 'Enter a valid number.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final token = context.read<SessionProvider>().token;
    if (token == null) {
      _showMessage('You are not signed in. Please log in again.');
      return;
    }

    final objectiveId = _objectiveIdController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      final message = await _dashboardService.createProjectKpi(
        token: token,
        projectId: widget.args.projectId,
        objectiveId: objectiveId.isEmpty ? null : objectiveId,
        name: _nameController.text.trim(),
        baselineValue: _parseNumber(_baselineController.text)!,
        targetValue: _parseNumber(_targetController.text)!,
        aggregationMethod: _aggregationMethod,
        reportingPeriod: _reportingPeriod,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      _showMessage(message);
      context.pop(true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to create the KPI right now. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      appBar: AppBar(title: const Text('New KPI')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.args.projectTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _objectiveIdController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Objective ID (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      maxLength: 500,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Name',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Name is required.';
                        if (text.length < 5) {
                          return 'Name must be at least 5 characters.';
                        }
                        if (text.length > 500) {
                          return 'Name must be 500 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _numberField(
                            colorScheme,
                            controller: _baselineController,
                            label: 'Baseline value',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _numberField(
                            colorScheme,
                            controller: _targetController,
                            label: 'Target value',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      colorScheme,
                      label: 'Aggregation method',
                      value: _aggregationMethod,
                      options: _aggregationMethods,
                      onChanged: (value) =>
                          setState(() => _aggregationMethod = value),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      colorScheme,
                      label: 'Reporting period',
                      value: _reportingPeriod,
                      options: _reportingPeriods,
                      onChanged: (value) =>
                          setState(() => _reportingPeriod = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isSubmitting,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Description is required.';
                        if (text.length < 10) {
                          return 'Description must be at least 10 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
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
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting ? 'Creating…' : 'Create KPI',
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

  Widget _numberField(
    ColorScheme colorScheme, {
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSubmitting,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(colorScheme, labelText: label),
      validator: (value) => _validateNumber(value, label),
    );
  }

  Widget _dropdown(
    ColorScheme colorScheme, {
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDecoration(colorScheme, labelText: label),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: _isSubmitting
          ? null
          : (selected) {
              if (selected != null) onChanged(selected);
            },
      validator: (selected) => selected == null ? '$label is required.' : null,
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
