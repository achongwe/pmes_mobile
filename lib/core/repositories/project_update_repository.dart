import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/local_project_update.dart';
import '../services/local_database.dart';

class ProjectUpdateRepository {
  ProjectUpdateRepository({LocalDatabase? database, Uuid? uuid})
    : _database = database ?? LocalDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  Future<LocalProjectUpdate> writeProjectUpdate({
    required String projectId,
    required String name,
    required String description,
    required String filePath,
    required String fileName,
    DateTime? timestamp,
  }) async {
    if (projectId.trim().isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'Must not be empty.');
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Must not be empty.',
      );
    }
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'Must not be empty.');
    }

    final update = LocalProjectUpdate(
      localId: _uuid.v4(),
      projectId: projectId,
      name: normalizedName,
      description: normalizedDescription,
      filePath: filePath,
      fileName: fileName,
      timestamp: (timestamp ?? DateTime.now()).toUtc(),
    );

    return _run('write project update', (database) async {
      final id = await database.insert('project_updates', update.toMap());
      return update.copyWith(id: id);
    });
  }

  Future<List<LocalProjectUpdate>> getPendingProjectUpdates() {
    return _run('fetch pending project updates', (database) async {
      final rows = await database.rawQuery('''
        SELECT project_updates.*, projects.title AS project_title
        FROM project_updates
        LEFT JOIN projects ON projects.id = project_updates.project_id
        WHERE project_updates.is_synced = 0
        ORDER BY project_updates."timestamp" ASC, project_updates.id ASC
      ''');
      return rows.map(LocalProjectUpdate.fromMap).toList(growable: false);
    });
  }

  Future<List<LocalProjectUpdate>> getProjectUpdatesForQueue() {
    return _run('fetch project updates for queue', (database) async {
      final rows = await database.rawQuery('''
        SELECT project_updates.*, projects.title AS project_title
        FROM project_updates
        LEFT JOIN projects ON projects.id = project_updates.project_id
        ORDER BY project_updates."timestamp" DESC, project_updates.id DESC
      ''');
      return rows.map(LocalProjectUpdate.fromMap).toList(growable: false);
    });
  }

  Future<void> markProjectUpdateSynced(String localId) {
    return _updateSyncState('mark project update synced', localId, {
      'is_synced': 1,
      'last_sync_attempt_at': DateTime.now().toUtc().toIso8601String(),
      'last_sync_error': null,
    });
  }

  Future<void> recordProjectUpdateSyncAttempt(
    String localId, {
    DateTime? attemptedAt,
  }) {
    return _updateSyncState('record project update sync attempt', localId, {
      'last_sync_attempt_at': (attemptedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'last_sync_error': null,
    });
  }

  Future<void> recordProjectUpdateSyncFailure(
    String localId,
    String message, {
    DateTime? attemptedAt,
  }) {
    final error = message.trim();
    if (error.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty.');
    }
    return _updateSyncState('record project update sync failure', localId, {
      'last_sync_attempt_at': (attemptedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'last_sync_error': error.length > 1000 ? error.substring(0, 1000) : error,
    });
  }

  Future<void> _updateSyncState(
    String operation,
    String localId,
    Map<String, Object?> values,
  ) {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Must not be empty.');
    }
    return _run(operation, (database) async {
      final updated = await database.update(
        'project_updates',
        values,
        where: 'local_id = ? AND is_synced = 0',
        whereArgs: [localId],
      );
      if (updated == 0) {
        final existing = await database.query(
          'project_updates',
          columns: ['is_synced'],
          where: 'local_id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (existing.isEmpty) {
          throw StateError('No project update exists with local ID $localId.');
        }
      }
    });
  }

  Future<T> _run<T>(
    String operation,
    Future<T> Function(Database database) action,
  ) async {
    try {
      return await action(await _database.database);
    } on DatabaseException catch (error) {
      throw LocalDatabaseException('Unable to $operation.', cause: error);
    }
  }
}
