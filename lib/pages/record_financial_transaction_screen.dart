import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/services/api_exception.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/session_provider.dart';

class RecordFinancialTransactionArgs {
  const RecordFinancialTransactionArgs({
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;
}

class RecordFinancialTransactionScreen extends StatefulWidget {
  const RecordFinancialTransactionScreen({required this.args, super.key});

  final RecordFinancialTransactionArgs args;

  @override
  State<RecordFinancialTransactionScreen> createState() =>
      _RecordFinancialTransactionScreenState();
}

class _RecordFinancialTransactionScreenState
    extends State<RecordFinancialTransactionScreen> {
  static const _dashboardService = DashboardService();
  static const _inputRadius = 12.0;

  final _formKey = GlobalKey<FormState>();
  final _objectiveIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarkController = TextEditingController();
  DateTime? _transactionDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _setTransactionDate(DateTime.now());
  }

  @override
  void dispose() {
    _objectiveIdController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _displayDate(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)} '
      '${_two(value.hour)}:${_two(value.minute)}';

  // ISO 8601 in UTC without fractional seconds, e.g. 2019-08-24T14:15:22Z.
  static String _isoDate(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${_two(utc.month)}-'
        '${_two(utc.day)}T${_two(utc.hour)}:${_two(utc.minute)}:'
        '${_two(utc.second)}Z';
  }

  void _setTransactionDate(DateTime value) {
    _transactionDate = value;
    _dateController.text = _displayDate(value);
  }

  Future<void> _pickDate() async {
    final current = _transactionDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _setTransactionDate(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    });
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
      final message = await _dashboardService.recordFinancialTransaction(
        token: token,
        projectId: widget.args.projectId,
        objectiveId: objectiveId.isEmpty ? null : objectiveId,
        amount: num.parse(_amountController.text.trim()),
        transactionDate: _isoDate(_transactionDate!),
        remark: _remarkController.text.trim(),
      );
      if (!mounted) return;
      _showMessage(message);
      context.pop(true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to record the expenditure right now. Please try again.',
        );
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
      appBar: AppBar(title: const Text('Record Expenditure')),
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
                      controller: _amountController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Amount',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Amount is required.';
                        final amount = num.tryParse(text);
                        if (amount == null) return 'Enter a valid number.';
                        if (amount < 1) return 'Amount must be at least 1.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      enabled: !_isSubmitting,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Transaction date',
                      ).copyWith(suffixIcon: const Icon(Icons.event_outlined)),
                      validator: (_) => _transactionDate == null
                          ? 'Transaction date is required.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarkController,
                      enabled: !_isSubmitting,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        colorScheme,
                        labelText: 'Remark',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Remark is required.';
                        if (text.length < 10) {
                          return 'Remark must be at least 10 characters.';
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
                    _isSubmitting ? 'Recording…' : 'Record expenditure',
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
