import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmes_mobile/core/models/local_project.dart';
import 'package:pmes_mobile/core/repositories/financial_transaction_repository.dart';
import 'package:pmes_mobile/core/repositories/field_log_repository.dart';
import 'package:pmes_mobile/core/services/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'financial transactions are persisted and can be marked synced',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pmes-financial-db-test-',
      );
      final localDatabase = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/test.db',
      );
      addTearDown(() async {
        await localDatabase.close();
        await directory.delete(recursive: true);
      });

      final projectRepository = FieldLogRepository(database: localDatabase);
      await projectRepository.saveProject(
        const LocalProject(id: 'project-1', title: 'Mupila Health Centre'),
      );
      final repository = FinancialTransactionRepository(
        database: localDatabase,
      );

      final created = await repository.writeFinancialTransaction(
        projectId: 'project-1',
        objectiveId: 'objective-1',
        amount: 1200.50,
        transactionDate: DateTime.utc(2026, 11, 1, 8, 30),
        remark: 'Procured materials for trenching and stabilization.',
      );

      expect(created.localId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(created.isSynced, isFalse);

      final pending = await repository.getPendingFinancialTransactions();
      expect(pending, hasLength(1));
      expect(pending.single.localId, created.localId);
      expect(pending.single.projectTitle, 'Mupila Health Centre');

      await repository.markFinancialTransactionSynced(created.localId);
      expect(await repository.getPendingFinancialTransactions(), isEmpty);

      final queue = await repository.getFinancialTransactionsForQueue();
      expect(queue, hasLength(1));
      expect(queue.single.localId, created.localId);
      expect(queue.single.isSynced, isTrue);
    },
  );

  test(
    'editing a financial transaction re-queues it with updated values',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pmes-financial-edit-db-test-',
      );
      final localDatabase = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/test.db',
      );
      addTearDown(() async {
        await localDatabase.close();
        await directory.delete(recursive: true);
      });

      final projectRepository = FieldLogRepository(database: localDatabase);
      await projectRepository.saveProject(
        const LocalProject(id: 'project-1', title: 'Mupila Health Centre'),
      );
      final repository = FinancialTransactionRepository(
        database: localDatabase,
      );
      final created = await repository.writeFinancialTransaction(
        projectId: 'project-1',
        amount: 850,
        transactionDate: DateTime.utc(2026, 11, 1, 8, 30),
        remark: 'Initial remark for record.',
      );

      await repository.markFinancialTransactionSynced(created.localId);
      await repository.updateFinancialTransaction(
        localId: created.localId,
        objectiveId: 'objective-99',
        amount: 990.25,
        transactionDate: DateTime.utc(2026, 11, 2, 10, 0),
        remark: 'Updated remark for edited queue entry.',
      );

      final pending = await repository.getPendingFinancialTransactions();
      expect(pending, hasLength(1));
      expect(pending.single.localId, created.localId);
      expect(pending.single.objectiveId, 'objective-99');
      expect(pending.single.amount, 990.25);
      expect(pending.single.transactionDate, DateTime.utc(2026, 11, 2, 10));
      expect(pending.single.remark, 'Updated remark for edited queue entry.');
      expect(pending.single.isSynced, isFalse);
    },
  );
}
