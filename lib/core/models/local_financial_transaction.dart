class LocalFinancialTransaction {
  const LocalFinancialTransaction({
    this.id,
    required this.localId,
    required this.projectId,
    this.objectiveId,
    required this.amount,
    required this.transactionDate,
    required this.remark,
    required this.timestamp,
    this.isSynced = false,
    this.projectTitle,
    this.lastSyncAttemptAt,
    this.lastSyncError,
  });

  final int? id;
  final String localId;
  final String projectId;
  final String? objectiveId;
  final double amount;
  final DateTime transactionDate;
  final String remark;
  final DateTime timestamp;
  final bool isSynced;
  final String? projectTitle;
  final DateTime? lastSyncAttemptAt;
  final String? lastSyncError;

  factory LocalFinancialTransaction.fromMap(Map<String, Object?> map) {
    return LocalFinancialTransaction(
      id: map['id'] as int?,
      localId: map['local_id']! as String,
      projectId: map['project_id']! as String,
      objectiveId: map['objective_id'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      transactionDate: DateTime.parse(map['transaction_date']! as String)
          .toUtc(),
      remark: map['remark'] as String? ?? '',
      timestamp: DateTime.parse(map['timestamp']! as String).toUtc(),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      projectTitle: map['project_title'] as String?,
      lastSyncAttemptAt: map['last_sync_attempt_at'] == null
          ? null
          : DateTime.parse(map['last_sync_attempt_at']! as String).toUtc(),
      lastSyncError: map['last_sync_error'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'local_id': localId,
    'project_id': projectId,
    'objective_id': objectiveId,
    'amount': amount,
    'transaction_date': transactionDate.toUtc().toIso8601String(),
    'remark': remark,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
    'last_sync_attempt_at': lastSyncAttemptAt?.toUtc().toIso8601String(),
    'last_sync_error': lastSyncError,
  };

  LocalFinancialTransaction copyWith({int? id}) {
    return LocalFinancialTransaction(
      id: id ?? this.id,
      localId: localId,
      projectId: projectId,
      objectiveId: objectiveId,
      amount: amount,
      transactionDate: transactionDate,
      remark: remark,
      timestamp: timestamp,
      isSynced: isSynced,
      projectTitle: projectTitle,
      lastSyncAttemptAt: lastSyncAttemptAt,
      lastSyncError: lastSyncError,
    );
  }
}
