class LocalProjectUpdate {
  const LocalProjectUpdate({
    this.id,
    required this.localId,
    required this.projectId,
    required this.name,
    required this.description,
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    this.isSynced = false,
    this.projectTitle,
    this.lastSyncAttemptAt,
    this.lastSyncError,
  });

  final int? id;
  final String localId;
  final String projectId;
  final String name;
  final String description;
  final String filePath;
  final String fileName;
  final DateTime timestamp;
  final bool isSynced;
  final String? projectTitle;
  final DateTime? lastSyncAttemptAt;
  final String? lastSyncError;

  factory LocalProjectUpdate.fromMap(Map<String, Object?> map) {
    return LocalProjectUpdate(
      id: map['id'] as int?,
      localId: map['local_id']! as String,
      projectId: map['project_id']! as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      filePath: map['file_path']! as String,
      fileName: map['file_name'] as String? ?? '',
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
    'name': name,
    'description': description,
    'file_path': filePath,
    'file_name': fileName,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
    'last_sync_attempt_at': lastSyncAttemptAt?.toUtc().toIso8601String(),
    'last_sync_error': lastSyncError,
  };

  LocalProjectUpdate copyWith({int? id}) {
    return LocalProjectUpdate(
      id: id ?? this.id,
      localId: localId,
      projectId: projectId,
      name: name,
      description: description,
      filePath: filePath,
      fileName: fileName,
      timestamp: timestamp,
      isSynced: isSynced,
      projectTitle: projectTitle,
      lastSyncAttemptAt: lastSyncAttemptAt,
      lastSyncError: lastSyncError,
    );
  }
}
