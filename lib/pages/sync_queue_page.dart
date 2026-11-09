import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/repositories/financial_transaction_repository.dart';
import '../core/repositories/field_log_repository.dart';
import '../core/repositories/project_update_repository.dart';
import '../core/services/connectivity_provider.dart';
import '../core/services/sync_service.dart';
import '../core/theme/app_colors.dart';

enum _QueueStatus { pending, syncing, synced, failed }

class _QueueRecord {
  const _QueueRecord({
    required this.type,
    required this.reference,
    required this.project,
    required this.status,
    required this.lastAttempt,
    this.objectiveId,
    this.amount,
    this.transactionDate,
    this.remark,
    this.kpisMet,
    this.notes,
    this.updateName,
    this.updateDescription,
    this.fileName,
    this.errorReason,
  });

  final String type;
  final String reference;
  final String project;
  final _QueueStatus status;
  final DateTime lastAttempt;
  final String? objectiveId;
  final double? amount;
  final DateTime? transactionDate;
  final String? remark;
  final String? kpisMet;
  final String? notes;
  final String? updateName;
  final String? updateDescription;
  final String? fileName;
  final String? errorReason;

  bool get isFinancialTransaction => amount != null;
  bool get isProjectUpdate => updateName != null;

  _QueueRecord copyWith({
    _QueueStatus? status,
    DateTime? lastAttempt,
    String? errorReason,
    bool clearError = false,
  }) {
    return _QueueRecord(
      type: type,
      reference: reference,
      project: project,
      status: status ?? this.status,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      objectiveId: objectiveId,
      amount: amount,
      transactionDate: transactionDate,
      remark: remark,
      kpisMet: kpisMet,
      notes: notes,
      updateName: updateName,
      updateDescription: updateDescription,
      fileName: fileName,
      errorReason: clearError ? null : errorReason ?? this.errorReason,
    );
  }
}

class SyncQueuePage extends StatefulWidget {
  const SyncQueuePage({super.key});

  @override
  State<SyncQueuePage> createState() => _SyncQueuePageState();
}

class _SyncQueuePageState extends State<SyncQueuePage> {
  final FieldLogRepository _fieldLogRepository = FieldLogRepository();
  final FinancialTransactionRepository _financialTransactionRepository =
      FinancialTransactionRepository();
  final ProjectUpdateRepository _projectUpdateRepository =
      ProjectUpdateRepository();
  List<_QueueRecord> _records = const [];
  bool _isLoading = true;
  String? _loadError;
  String? _operationError;
  SyncService? _observedSyncService;
  bool _wasSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final syncService = context.read<SyncService>();
    if (!identical(_observedSyncService, syncService)) {
      _observedSyncService?.removeListener(_onSyncServiceChanged);
      _observedSyncService = syncService;
      _wasSyncing = syncService.isSyncing;
      syncService.addListener(_onSyncServiceChanged);
    }
  }

  void _onSyncServiceChanged() {
    final syncService = _observedSyncService;
    if (!mounted || syncService == null) return;
    final isSyncing = syncService.isSyncing;
    final syncJustFinished = _wasSyncing && !isSyncing;
    _wasSyncing = isSyncing;
    setState(() {});
    if (syncJustFinished) {
      _loadQueue(showLoading: false);
    }
  }

  Future<void> _loadQueue({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final pendingLogs = await _fieldLogRepository.getPendingFieldLogs();
      final financialTransactions = await _financialTransactionRepository
          .getFinancialTransactionsForQueue();
      final projectUpdates = await _projectUpdateRepository
          .getProjectUpdatesForQueue();
      final fieldRecords = pendingLogs
          .map(
            (log) => _QueueRecord(
              type: 'Progress report',
              reference: log.localId,
              project: log.projectTitle ?? 'Project ${log.projectId}',
              status: log.lastSyncError == null
                  ? _QueueStatus.pending
                  : _QueueStatus.failed,
              lastAttempt: log.lastSyncAttemptAt ?? log.timestamp,
              kpisMet: log.kpisMet,
              notes: log.notes,
              errorReason: log.lastSyncError,
            ),
          )
          .toList(growable: false);
      final financialRecords = financialTransactions
          .map(
            (transaction) => _QueueRecord(
              type: 'Financial transaction',
              reference: transaction.localId,
              project:
                  transaction.projectTitle ??
                  'Project ${transaction.projectId}',
              status: transaction.isSynced
                  ? _QueueStatus.synced
                  : transaction.lastSyncError == null
                  ? _QueueStatus.pending
                  : _QueueStatus.failed,
              lastAttempt:
                  transaction.lastSyncAttemptAt ?? transaction.transactionDate,
              objectiveId: transaction.objectiveId,
              amount: transaction.amount,
              transactionDate: transaction.transactionDate,
              remark: transaction.remark,
              errorReason: transaction.lastSyncError,
            ),
          )
          .toList(growable: false);
      final updateRecords = projectUpdates
          .map(
            (update) => _QueueRecord(
              type: 'Project update',
              reference: update.localId,
              project: update.projectTitle ?? 'Project ${update.projectId}',
              status: update.isSynced
                  ? _QueueStatus.synced
                  : update.lastSyncError == null
                  ? _QueueStatus.pending
                  : _QueueStatus.failed,
              lastAttempt: update.lastSyncAttemptAt ?? update.timestamp,
              updateName: update.name,
              updateDescription: update.description,
              fileName: update.fileName,
              errorReason: update.lastSyncError,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _records = [...financialRecords, ...updateRecords, ...fieldRecords]
          ..sort((a, b) => b.lastAttempt.compareTo(a.lastAttempt));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Unable to load the sync queue. Please try again. ($error)';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncPending() async {
    final connectivity = context.read<ConnectivityProvider>();
    final syncService = context.read<SyncService>();
    if (!connectivity.isOnline) {
      setState(() {
        _operationError = 'You are offline. Your records remain stored on this device until upload is available.';
      });
      return;
    }

    final hasPending = _records.any(
      (record) =>
          record.status == _QueueStatus.pending ||
          record.status == _QueueStatus.failed,
    );
    if (!hasPending && !syncService.isSyncing) {
      setState(() {
        _operationError = 'There are no pending uploads to sync.';
      });
      return;
    }

    setState(() => _operationError = null);
    await syncService.syncPending();
    if (!mounted) return;
    if (syncService.lastError != null) {
      setState(() => _operationError = syncService.lastError);
    }
  }

  Future<void> _retryRecord() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (!connectivity.isOnline) {
      setState(() {
        _operationError = 'You are offline. This record will remain stored locally until you reconnect.';
      });
      return;
    }
    await _syncPending();
  }

  void _openRecord(_QueueRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                record.type,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                record.reference,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _DetailRow(label: 'Project / district', value: record.project),
              _DetailRow(
                label: 'Queue status',
                value: _statusLabel(record.status),
              ),
              _DetailRow(
                label: 'Recorded',
                value: _timeSince(record.lastAttempt),
              ),
              if (record.isFinancialTransaction) ...[
                _DetailRow(
                  label: 'Amount',
                  value: record.amount!.toStringAsFixed(2),
                ),
                _DetailRow(
                  label: 'Objective',
                  value: record.objectiveId?.isNotEmpty == true
                      ? record.objectiveId!
                      : 'No objective',
                ),
                _DetailRow(
                  label: 'Transaction date',
                  value: _dateTimeLabel(record.transactionDate!),
                ),
                _DetailRow(label: 'Remark', value: record.remark ?? '—'),
              ] else if (record.isProjectUpdate) ...[
                _DetailRow(label: 'Name', value: record.updateName!),
                _DetailRow(
                  label: 'Description',
                  value: record.updateDescription ?? '—',
                ),
                _DetailRow(label: 'File', value: record.fileName ?? '—'),
              ] else ...[
                _DetailRow(label: 'KPIs met', value: record.kpisMet ?? '—'),
                _DetailRow(label: 'Notes', value: record.notes ?? '—'),
              ],
              if (record.errorReason != null) ...[
                const SizedBox(height: 12),
                _ErrorMessage(message: record.errorReason!),
              ],
              if (record.isFinancialTransaction &&
                  record.status != _QueueStatus.synced) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _editFinancialRecord(record);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit record'),
                  ),
                ),
              ],
              if (record.status == _QueueStatus.failed) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _retryRecord();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry upload'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editFinancialRecord(_QueueRecord record) async {
    final amountController = TextEditingController(
      text: record.amount!.toStringAsFixed(2),
    );
    final objectiveController = TextEditingController(
      text: record.objectiveId ?? '',
    );
    final remarkController = TextEditingController(text: record.remark ?? '');
    DateTime selectedDate = record.transactionDate ?? DateTime.now();
    var isSaving = false;
    String? formError;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickDateTime() async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(selectedDate),
            );
            if (time == null || !context.mounted) return;
            setModalState(() {
              selectedDate = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Edit financial record',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Amount'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Amount is required.';
                          final amount = num.tryParse(text);
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount greater than 0.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: objectiveController,
                        decoration: const InputDecoration(
                          labelText: 'Objective ID (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: pickDateTime,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Transaction date',
                            suffixIcon: Icon(Icons.event_outlined),
                          ),
                          child: Text(_dateTimeLabel(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarkController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Remark'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Remark is required.';
                          if (text.length < 10) {
                            return 'Remark must be at least 10 characters.';
                          }
                          return null;
                        },
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorMessage(message: formError!),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() {
                                    isSaving = true;
                                    formError = null;
                                  });
                                  try {
                                    await _financialTransactionRepository
                                        .updateFinancialTransaction(
                                          localId: record.reference,
                                          objectiveId: objectiveController.text
                                              .trim(),
                                          amount: num.parse(
                                            amountController.text.trim(),
                                          ),
                                          transactionDate: selectedDate,
                                          remark: remarkController.text.trim(),
                                        );
                                    if (!context.mounted || !mounted) return;
                                    Navigator.of(context).pop();
                                    await _loadQueue(showLoading: false);
                                  } catch (error) {
                                    setModalState(() {
                                      formError =
                                          'Unable to update record. ($error)';
                                      isSaving = false;
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(isSaving ? 'Saving…' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    amountController.dispose();
    objectiveController.dispose();
    remarkController.dispose();
  }

  @override
  void dispose() {
    _observedSyncService?.removeListener(_onSyncServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final syncService = context.watch<SyncService>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading sync queue…'),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return _QueueErrorState(message: _loadError!, onRetry: _loadQueue);
    }

    final displayRecords = _records
        .map(
          (record) => record.reference == syncService.currentLocalId
              ? record.copyWith(status: _QueueStatus.syncing, clearError: true)
              : record,
        )
        .toList(growable: false);

    final counts = {
      _QueueStatus.pending: displayRecords
          .where((record) => record.status == _QueueStatus.pending)
          .length,
      _QueueStatus.syncing: displayRecords
          .where((record) => record.status == _QueueStatus.syncing)
          .length,
      _QueueStatus.synced: displayRecords
          .where((record) => record.status == _QueueStatus.synced)
          .length,
      _QueueStatus.failed: displayRecords
          .where((record) => record.status == _QueueStatus.failed)
          .length,
    };

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _SyncOverviewCard(
            isOnline: connectivity.isOnline,
            isChecking: connectivity.isChecking,
            isSyncing: syncService.isSyncing,
            onSync: _syncPending,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 2 ? 1.65 : 1.4,
                children: [
                  _StatCard(
                    label: 'Pending uploads',
                    value: counts[_QueueStatus.pending]!,
                    icon: Icons.schedule_rounded,
                    color: isDark ? colorScheme.secondary : AppColors.secondary,
                  ),
                  _StatCard(
                    label: 'Currently syncing',
                    value: counts[_QueueStatus.syncing]!,
                    icon: Icons.sync_rounded,
                    color: isDark
                        ? const Color(0xFFFFD166)
                        : const Color(0xFFB7791F),
                  ),
                  _StatCard(
                    label: 'Successfully synced',
                    value: counts[_QueueStatus.synced]!,
                    icon: Icons.check_circle_outline_rounded,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : AppColors.tertiaryDark,
                  ),
                  _StatCard(
                    label: 'Failed uploads',
                    value: counts[_QueueStatus.failed]!,
                    icon: Icons.error_outline_rounded,
                    color: colorScheme.error,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _OfflineInfoCard(isOnline: connectivity.isOnline),
          if (_operationError != null) ...[
            const SizedBox(height: 12),
            _ErrorMessage(
              message: _operationError!,
              onDismiss: () => setState(() => _operationError = null),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Queued records',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${displayRecords.length} records',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayRecords.isEmpty)
            const _EmptyQueueState()
          else
            for (var index = 0; index < displayRecords.length; index++) ...[
              _QueueRecordCard(
                record: displayRecords[index],
                onTap: () => _openRecord(displayRecords[index]),
                onRetry: displayRecords[index].status == _QueueStatus.failed
                    ? _retryRecord
                    : null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _SyncOverviewCard extends StatelessWidget {
  const _SyncOverviewCard({
    required this.isOnline,
    required this.isChecking,
    required this.isSyncing,
    required this.onSync,
  });

  final bool isOnline;
  final bool isChecking;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final connectionLabel = isChecking
        ? 'Checking connection'
        : isOnline
        ? 'Online'
        : 'Offline';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C43) : AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keep your data in sync',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your field records stay up to date across your team.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: isOnline ? const Color(0xFF6EE7B7) : Colors.amberAccent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                connectionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: isSyncing || !isOnline ? null : onSync,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                  minimumSize: const Size(126, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, size: 18),
                          SizedBox(width: 7),
                          Text(
                            'Sync now',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineInfoCard extends StatelessWidget {
  const _OfflineInfoCard({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: isDark ? 0.3 : 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: colorScheme.secondary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Field records are stored on this device and sync automatically when an internet connection is available.',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRecordCard extends StatelessWidget {
  const _QueueRecordCard({
    required this.record,
    required this.onTap,
    this.onRetry,
  });

  final _QueueRecord record;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, record.status);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.type,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.reference,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: record.status),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.project,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    _timeSince(record.lastAttempt),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (record.status == _QueueStatus.syncing) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: colorScheme.secondary.withValues(
                      alpha: 0.18,
                    ),
                    valueColor: AlwaysStoppedAnimation(colorScheme.secondary),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Uploading…',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (record.status == _QueueStatus.failed) ...[
                const SizedBox(height: 12),
                _ErrorMessage(message: record.errorReason!),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _QueueStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}

class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your queue is clear',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New field records will appear here when they are ready to sync.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueErrorState extends StatelessWidget {
  const _QueueErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 42, color: errorColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, _QueueStatus status) {
  final colorScheme = Theme.of(context).colorScheme;
  if (colorScheme.brightness == Brightness.dark) {
    return switch (status) {
      _QueueStatus.pending => colorScheme.secondary,
      _QueueStatus.syncing => const Color(0xFFFFD166),
      _QueueStatus.synced => const Color(0xFF6EE7B7),
      _QueueStatus.failed => colorScheme.error,
    };
  }
  return switch (status) {
    _QueueStatus.pending => AppColors.secondary,
    _QueueStatus.syncing => const Color(0xFFB7791F),
    _QueueStatus.synced => AppColors.tertiaryDark,
    _QueueStatus.failed => AppColors.error,
  };
}

String _statusLabel(_QueueStatus status) => switch (status) {
  _QueueStatus.pending => 'Pending',
  _QueueStatus.syncing => 'Syncing',
  _QueueStatus.synced => 'Synced',
  _QueueStatus.failed => 'Failed',
};

String _dateTimeLabel(DateTime timestamp) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = timestamp.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _timeSince(DateTime timestamp) {
  final elapsed = DateTime.now().difference(timestamp);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}
