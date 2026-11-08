import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/local_financial_transaction.dart';
import '../services/local_database.dart';

class FinancialTransactionRepository {
  FinancialTransactionRepository({LocalDatabase? database, Uuid? uuid})
    : _database = database ?? LocalDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  Future<LocalFinancialTransaction> writeFinancialTransaction({
    required String projectId,
    String? objectiveId,
    required num amount,
    required DateTime transactionDate,
    required String remark,
    DateTime? timestamp,
  }) async {
    if (projectId.trim().isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'Must not be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than 0.');
    }
    final normalizedRemark = remark.trim();
    if (normalizedRemark.isEmpty) {
      throw ArgumentError.value(remark, 'remark', 'Must not be empty.');
    }

    final transaction = LocalFinancialTransaction(
      localId: _uuid.v4(),
      projectId: projectId,
      objectiveId: objectiveId?.trim().isEmpty == true ? null : objectiveId,
      amount: amount.toDouble(),
      transactionDate: transactionDate.toUtc(),
      remark: normalizedRemark,
      timestamp: (timestamp ?? DateTime.now()).toUtc(),
    );

    return _run('write financial transaction', (database) async {
      final id = await database.insert(
        'financial_transactions',
        transaction.toMap(),
      );
      return transaction.copyWith(id: id);
    });
  }

  Future<List<LocalFinancialTransaction>> getPendingFinancialTransactions() {
    return _run('fetch pending financial transactions', (database) async {
      final rows = await database.rawQuery('''
        SELECT financial_transactions.*, projects.title AS project_title
        FROM financial_transactions
        LEFT JOIN projects ON projects.id = financial_transactions.project_id
        WHERE financial_transactions.is_synced = 0
        ORDER BY financial_transactions."timestamp" ASC, financial_transactions.id ASC
      ''');
      return rows
          .map(LocalFinancialTransaction.fromMap)
          .toList(growable: false);
    });
  }

  Future<List<LocalFinancialTransaction>> getFinancialTransactionsForQueue() {
    return _run('fetch financial transactions for queue', (database) async {
      final rows = await database.rawQuery('''
        SELECT financial_transactions.*, projects.title AS project_title
        FROM financial_transactions
        LEFT JOIN projects ON projects.id = financial_transactions.project_id
        ORDER BY financial_transactions."timestamp" DESC, financial_transactions.id DESC
      ''');
      return rows
          .map(LocalFinancialTransaction.fromMap)
          .toList(growable: false);
    });
  }

  Future<void> markFinancialTransactionSynced(String localId) {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Must not be empty.');
    }
    return _run('mark financial transaction synced', (database) async {
      final updated = await database.update(
        'financial_transactions',
        {
          'is_synced': 1,
          'last_sync_attempt_at': DateTime.now().toUtc().toIso8601String(),
          'last_sync_error': null,
        },
        where: 'local_id = ? AND is_synced = 0',
        whereArgs: [localId],
      );
      if (updated == 0) {
        final existing = await database.query(
          'financial_transactions',
          columns: ['is_synced'],
          where: 'local_id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (existing.isEmpty) {
          throw StateError(
            'No financial transaction exists with local ID $localId.',
          );
        }
      }
    });
  }

  Future<void> recordFinancialTransactionSyncAttempt(
    String localId, {
    DateTime? attemptedAt,
  }) {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Must not be empty.');
    }
    return _run('record financial transaction sync attempt', (database) async {
      final updated = await database.update(
        'financial_transactions',
        {
          'last_sync_attempt_at': (attemptedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'last_sync_error': null,
        },
        where: 'local_id = ? AND is_synced = 0',
        whereArgs: [localId],
      );
      if (updated == 0) {
        final existing = await database.query(
          'financial_transactions',
          columns: ['is_synced'],
          where: 'local_id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (existing.isEmpty) {
          throw StateError(
            'No financial transaction exists with local ID $localId.',
          );
        }
      }
    });
  }

  Future<void> recordFinancialTransactionSyncFailure(
    String localId,
    String message, {
    DateTime? attemptedAt,
  }) {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Must not be empty.');
    }
    final error = message.trim();
    if (error.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Must not be empty.');
    }
    return _run('record financial transaction sync failure', (database) async {
      final updated = await database.update(
        'financial_transactions',
        {
          'last_sync_attempt_at': (attemptedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          'last_sync_error': error.length > 1000
              ? error.substring(0, 1000)
              : error,
        },
        where: 'local_id = ? AND is_synced = 0',
        whereArgs: [localId],
      );
      if (updated == 0) {
        final existing = await database.query(
          'financial_transactions',
          columns: ['is_synced'],
          where: 'local_id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (existing.isEmpty) {
          throw StateError(
            'No financial transaction exists with local ID $localId.',
          );
        }
      }
    });
  }

  Future<void> updateFinancialTransaction({
    required String localId,
    String? objectiveId,
    required num amount,
    required DateTime transactionDate,
    required String remark,
  }) {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Must not be empty.');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than 0.');
    }
    final normalizedRemark = remark.trim();
    if (normalizedRemark.isEmpty) {
      throw ArgumentError.value(remark, 'remark', 'Must not be empty.');
    }
    return _run('update financial transaction', (database) async {
      final updated = await database.update(
        'financial_transactions',
        {
          'objective_id': objectiveId?.trim().isEmpty == true
              ? null
              : objectiveId?.trim(),
          'amount': amount.toDouble(),
          'transaction_date': transactionDate.toUtc().toIso8601String(),
          'remark': normalizedRemark,
          'is_synced': 0,
          'last_sync_attempt_at': null,
          'last_sync_error': null,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      if (updated == 0) {
        throw StateError(
          'No financial transaction exists with local ID $localId.',
        );
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
