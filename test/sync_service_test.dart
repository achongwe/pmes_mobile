import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pmes_mobile/core/constants/api_constants.dart';
import 'package:pmes_mobile/core/repositories/financial_transaction_repository.dart';
import 'package:pmes_mobile/core/repositories/field_log_repository.dart';
import 'package:pmes_mobile/core/services/local_database.dart';
import 'package:pmes_mobile/core/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('sends batch payload and marks a successful record synced', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.dispose);
    final log = await fixture.repository.writeFieldLog(
      projectId: 'project-1',
      kpisMet: '2 of 5',
      notes: 'Work is progressing.',
      gpsLatitude: -15.4,
      gpsLongitude: 28.2,
      timestamp: DateTime.utc(2026, 10, 29, 12),
    );
    late final http.Request sentRequest;

    final service = SyncService(
      repository: fixture.repository,
      financialTransactionRepository: fixture.financialRepository,
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'message': 'Sync completed successfully.',
            'synced_items': [
              {
                'local_id': log.localId,
                'server_id': 'server-1',
                'status': 'success',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final finished = _whenSyncFinishes(service);
    service.updateDependencies(isOnline: true, token: 'test-token');
    await finished;

    expect(sentRequest.url.toString(), ApiConstants.syncBatch);
    expect(sentRequest.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(sentRequest.body), {
      'items': [
        [
          log.localId,
          'project-1',
          '2 of 5',
          'Work is progressing.',
          '-15.4',
          '28.2',
          '2026-10-29T12:00:00.000Z',
        ],
      ],
    });
    expect(await fixture.repository.getPendingFieldLogs(), isEmpty);
    expect(service.completedCount, 1);
    expect(service.failedCount, 0);
  });

  test('sends batches of at most 100 records', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.dispose);
    for (var index = 0; index < 101; index++) {
      await fixture.repository.writeFieldLog(
        projectId: 'project-1',
        kpisMet: '$index',
        notes: 'Log $index',
      );
    }

    final batchSizes = <int>[];
    final service = SyncService(
      repository: fixture.repository,
      financialTransactionRepository: fixture.financialRepository,
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final items = body['items'] as List<dynamic>;
        batchSizes.add(items.length);
        return http.Response(
          jsonEncode({
            'message': 'Sync completed successfully.',
            'synced_items': items
                .map(
                  (item) => {
                    'local_id': (item as List<dynamic>).first,
                    'server_id': 'server-id',
                    'status': 'success',
                  },
                )
                .toList(),
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final finished = _whenSyncFinishes(service);
    service.updateDependencies(isOnline: true, token: 'test-token');
    await finished;

    expect(batchSizes, [100, 1]);
    expect(await fixture.repository.getPendingFieldLogs(), isEmpty);
    expect(service.completedCount, 101);
    expect(service.failedCount, 0);
  });

  test('retains per-item errors from a partially successful batch', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.dispose);
    final successfulLog = await fixture.repository.writeFieldLog(
      projectId: 'project-1',
      kpisMet: '2 of 5',
      notes: 'Successful log.',
    );
    final failedLog = await fixture.repository.writeFieldLog(
      projectId: 'project-2',
      kpisMet: '1 of 3',
      notes: 'Failed log.',
    );
    late final http.Request sentRequest;
    final service = SyncService(
      repository: fixture.repository,
      financialTransactionRepository: fixture.financialRepository,
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'message': 'Sync completed with errors.',
            'synced_items': [
              {'local_id': successfulLog.localId, 'status': 'success'},
              {
                'local_id': failedLog.localId,
                'status': 'error',
                'message': 'Invalid project.',
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final finished = _whenSyncFinishes(service);
    service.updateDependencies(isOnline: true, token: 'test-token');
    await finished;

    final requestBody = jsonDecode(sentRequest.body) as Map<String, dynamic>;
    final items = requestBody['items'] as List<dynamic>;
    final failedItem = items.cast<List<dynamic>>().singleWhere(
      (item) => item.first == failedLog.localId,
    );
    expect(failedItem, everyElement(isA<String>()));
    expect(failedItem[4], '');
    expect(failedItem[5], '');

    final pending = await fixture.repository.getPendingFieldLogs();
    expect(pending, hasLength(1));
    expect(pending.single.localId, failedLog.localId);
    expect(pending.single.lastSyncError, 'Invalid project.');
    expect(service.completedCount, 1);
    expect(service.failedCount, 1);
  });

  test(
    'retains failed uploads and persists the server error for retry',
    () async {
      final fixture = await _createFixture();
      addTearDown(fixture.dispose);
      final log = await fixture.repository.writeFieldLog(
        projectId: 'project-1',
        kpisMet: '2 of 5',
        notes: 'Work is progressing.',
        timestamp: DateTime.utc(2026, 10, 29, 12),
      );
      final service = SyncService(
        repository: fixture.repository,
        financialTransactionRepository: fixture.financialRepository,
        client: MockClient(
          (_) async => http.Response('{"message":"Invalid project."}', 422),
        ),
      );
      addTearDown(service.dispose);

      final finished = _whenSyncFinishes(service);
      service.updateDependencies(isOnline: true, token: 'test-token');
      await finished;

      final pending = await fixture.repository.getPendingFieldLogs();
      expect(pending, hasLength(1));
      expect(pending.single.localId, log.localId);
      expect(pending.single.isSynced, isFalse);
      expect(pending.single.lastSyncError, 'Invalid project.');
      expect(pending.single.lastSyncAttemptAt, isNotNull);
      expect(service.failedCount, 1);
    },
  );

  test('syncs pending financial transactions and marks them synced', () async {
    final fixture = await _createFixture();
    addTearDown(fixture.dispose);
    final transaction = await fixture.financialRepository
        .writeFinancialTransaction(
          projectId: 'project-1',
          objectiveId: 'objective-1',
          amount: 500,
          transactionDate: DateTime.utc(2026, 11, 1, 8, 30),
          remark: 'Materials purchased for site works.',
        );
    late final http.Request sentRequest;
    final service = SyncService(
      repository: fixture.repository,
      financialTransactionRepository: fixture.financialRepository,
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response('{"message":"Saved"}', 201);
      }),
    );
    addTearDown(service.dispose);

    final finished = _whenSyncFinishes(service);
    service.updateDependencies(isOnline: true, token: 'test-token');
    await finished;

    expect(
      sentRequest.url.toString(),
      ApiConstants.projectFinancialTransactions('project-1'),
    );
    expect(
      await fixture.financialRepository.getPendingFinancialTransactions(),
      isEmpty,
    );
    expect(service.completedCount, 1);
    expect(service.failedCount, 0);

    final queue = await fixture.financialRepository
        .getFinancialTransactionsForQueue();
    expect(queue.single.localId, transaction.localId);
    expect(queue.single.isSynced, isTrue);
  });

  test(
    'retains failed financial uploads and persists the server error for retry',
    () async {
      final fixture = await _createFixture();
      addTearDown(fixture.dispose);
      final transaction = await fixture.financialRepository
          .writeFinancialTransaction(
            projectId: 'project-1',
            amount: 900,
            transactionDate: DateTime.utc(2026, 11, 1, 8, 30),
            remark: 'Community engagement transport costs.',
          );
      final service = SyncService(
        repository: fixture.repository,
        financialTransactionRepository: fixture.financialRepository,
        client: MockClient(
          (_) async => http.Response('{"message":"Invalid objective."}', 422),
        ),
      );
      addTearDown(service.dispose);

      final finished = _whenSyncFinishes(service);
      service.updateDependencies(isOnline: true, token: 'test-token');
      await finished;

      final pending = await fixture.financialRepository
          .getPendingFinancialTransactions();
      expect(pending, hasLength(1));
      expect(pending.single.localId, transaction.localId);
      expect(pending.single.lastSyncError, 'Invalid objective.');
      expect(pending.single.lastSyncAttemptAt, isNotNull);
      expect(service.failedCount, 1);
    },
  );
}

Future<void> _whenSyncFinishes(SyncService service) {
  final completer = Completer<void>();
  void listener() {
    if (!service.isSyncing &&
        service.totalCount > 0 &&
        !completer.isCompleted) {
      completer.complete();
    }
  }

  service.addListener(listener);
  return completer.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(() => service.removeListener(listener));
}

Future<_SyncFixture> _createFixture() async {
  final directory = await Directory.systemTemp.createTemp('pmes-sync-test-');
  final database = LocalDatabase(
    factory: databaseFactoryFfi,
    databasePath: '${directory.path}/sync-test.db',
  );
  return _SyncFixture(
    directory: directory,
    database: database,
    repository: FieldLogRepository(database: database),
    financialRepository: FinancialTransactionRepository(database: database),
  );
}

class _SyncFixture {
  const _SyncFixture({
    required this.directory,
    required this.database,
    required this.repository,
    required this.financialRepository,
  });

  final Directory directory;
  final LocalDatabase database;
  final FieldLogRepository repository;
  final FinancialTransactionRepository financialRepository;

  Future<void> dispose() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
