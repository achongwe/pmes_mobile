import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/api_constants.dart';
import '../models/field_progress_log.dart';
import '../models/local_financial_transaction.dart';
import '../models/local_project_update.dart';
import '../repositories/financial_transaction_repository.dart';
import '../repositories/field_log_repository.dart';
import '../repositories/project_update_repository.dart';
import 'api_exception.dart';
import 'dashboard_service.dart';

class SyncUploadException implements Exception {
  const SyncUploadException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() => message;
}

class SyncService extends ChangeNotifier {
  SyncService({
    required this.repository,
    FinancialTransactionRepository? financialTransactionRepository,
    ProjectUpdateRepository? projectUpdateRepository,
    DashboardService dashboardService = const DashboardService(),
    http.Client? client,
  }) : financialTransactionRepository =
           financialTransactionRepository ?? FinancialTransactionRepository(),
       projectUpdateRepository =
           projectUpdateRepository ?? ProjectUpdateRepository(),
       _dashboardService = dashboardService,
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _batchSize = 100;

  final FieldLogRepository repository;
  final FinancialTransactionRepository financialTransactionRepository;
  final ProjectUpdateRepository projectUpdateRepository;
  final DashboardService _dashboardService;
  final http.Client _client;
  final bool _ownsClient;

  bool _isOnline = false;
  bool _isSyncing = false;
  bool _syncAgainRequested = false;
  String? _token;
  String? _currentLocalId;
  String? _lastError;
  int _completedCount = 0;
  int _failedCount = 0;
  int _totalCount = 0;

  bool get isSyncing => _isSyncing;
  String? get currentLocalId => _currentLocalId;
  String? get lastError => _lastError;
  int get completedCount => _completedCount;
  int get failedCount => _failedCount;
  int get totalCount => _totalCount;

  void updateDependencies({required bool isOnline, required String? token}) {
    final shouldStartSync =
        isOnline &&
        token != null &&
        token.isNotEmpty &&
        (!_isOnline || token != _token);
    _isOnline = isOnline;
    _token = token;
    if (shouldStartSync) {
      if (_isSyncing) {
        _syncAgainRequested = true;
      } else {
        scheduleMicrotask(() => syncPending());
      }
    }
  }

  Future<void> syncPending() async {
    if (_isSyncing) return;
    if (!_isOnline) {
      _lastError = 'Cannot sync while offline.';
      notifyListeners();
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      _lastError = 'Sign in before syncing field updates.';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _lastError = null;
    _currentLocalId = null;
    _completedCount = 0;
    _failedCount = 0;
    _totalCount = 0;
    notifyListeners();

    try {
      final pendingLogs = await repository.getPendingFieldLogs();
      final pendingTransactions = await financialTransactionRepository
          .getPendingFinancialTransactions();
      final pendingUpdates = await projectUpdateRepository
          .getPendingProjectUpdates();
      _totalCount =
          pendingLogs.length +
          pendingTransactions.length +
          pendingUpdates.length;
      notifyListeners();

      for (var start = 0; start < pendingLogs.length; start += _batchSize) {
        if (!_isOnline) {
          _lastError = 'Connection lost. Remaining records are still queued.';
          break;
        }
        if (_token != token) {
          _lastError = 'Your session changed. Sign in again before syncing remaining records.';
          break;
        }

        final batch = pendingLogs
            .skip(start)
            .take(_batchSize)
            .toList(growable: false);
        _currentLocalId = batch.first.localId;
        notifyListeners();

        Map<String, String?> outcomes;
        var stopAfterBatch = false;
        try {
          for (final log in batch) {
            await repository.recordFieldLogSyncAttempt(log.localId);
          }
          outcomes = await _uploadFieldLogs(batch, token);
        } on Object catch (error) {
          final message = _errorMessage(error);
          outcomes = {for (final log in batch) log.localId: message};
          stopAfterBatch = error is SyncUploadException && error.isTransient;
        }

        for (final log in batch) {
          _currentLocalId = log.localId;
          final error = outcomes[log.localId];
          try {
            if (error == null) {
              await repository.markFieldLogSynced(log.localId);
              _completedCount++;
            } else {
              await repository.recordFieldLogSyncFailure(log.localId, error);
              _failedCount++;
              _lastError ??= error;
            }
          } on Object catch (storageError) {
            stopAfterBatch = true;
            _lastError =
                'Unable to save the sync result for ${log.localId}: '
                '${_errorMessage(storageError)}';
            debugPrint(
              'Unable to save sync result for ${log.localId}: $storageError',
            );
            break;
          }
          notifyListeners();
        }
        if (stopAfterBatch) break;
      }

      if (_lastError == null || pendingTransactions.isNotEmpty) {
        for (final transaction in pendingTransactions) {
          if (!_isOnline) {
            _lastError = 'Connection lost. Remaining records are still queued.';
            break;
          }
          if (_token != token) {
            _lastError = 'Your session changed. Sign in again before syncing remaining records.';
            break;
          }

          _currentLocalId = transaction.localId;
          notifyListeners();

          var stopAfterRecord = false;
          try {
            await financialTransactionRepository
                .recordFinancialTransactionSyncAttempt(transaction.localId);
            await _uploadFinancialTransaction(transaction, token);
            await financialTransactionRepository.markFinancialTransactionSynced(
              transaction.localId,
            );
            _completedCount++;
          } on Object catch (error) {
            final message = _errorMessage(error);
            try {
              await financialTransactionRepository
                  .recordFinancialTransactionSyncFailure(
                    transaction.localId,
                    message,
                  );
              _failedCount++;
              _lastError ??= message;
            } on Object catch (storageError) {
              _lastError =
                  'Unable to save the sync result for ${transaction.localId}: '
                  '${_errorMessage(storageError)}';
              debugPrint(
                'Unable to save sync result for '
                '${transaction.localId}: $storageError',
              );
              stopAfterRecord = true;
            }
            if (error is SyncUploadException && error.isTransient) {
              stopAfterRecord = true;
            }
          }
          notifyListeners();
          if (stopAfterRecord) break;
        }
      }

      for (final update in pendingUpdates) {
        if (!_isOnline) {
          _lastError = 'Connection lost. Remaining records are still queued.';
          break;
        }
        if (_token != token) {
          _lastError = 'Your session changed. Sign in again before syncing remaining records.';
          break;
        }

        _currentLocalId = update.localId;
        notifyListeners();

        var stopAfterRecord = false;
        try {
          await projectUpdateRepository.recordProjectUpdateSyncAttempt(
            update.localId,
          );
          await _uploadProjectUpdate(update, token);
          await projectUpdateRepository.markProjectUpdateSynced(update.localId);
          _completedCount++;
        } on Object catch (error) {
          final message = _errorMessage(error);
          try {
            await projectUpdateRepository.recordProjectUpdateSyncFailure(
              update.localId,
              message,
            );
            _failedCount++;
            _lastError ??= message;
          } on Object catch (storageError) {
            _lastError =
                'Unable to save the sync result for ${update.localId}: '
                '${_errorMessage(storageError)}';
            debugPrint(
              'Unable to save sync result for '
              '${update.localId}: $storageError',
            );
            stopAfterRecord = true;
          }
          if (_isTransientUploadError(error)) stopAfterRecord = true;
        }
        notifyListeners();
        if (stopAfterRecord) break;
      }
    } on Object catch (error) {
      _lastError =
          'Unable to read the pending sync queue: ${_errorMessage(error)}';
      debugPrint('Unable to read pending field updates: $error');
    } finally {
      _currentLocalId = null;
      _isSyncing = false;
      final retryRequested =
          _syncAgainRequested && _isOnline && _token?.isNotEmpty == true;
      _syncAgainRequested = false;
      notifyListeners();
      if (retryRequested) {
        scheduleMicrotask(() => syncPending());
      }
    }
  }

  Future<Map<String, String?>> _uploadFieldLogs(
    List<FieldProgressLog> logs,
    String token,
  ) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(ApiConstants.syncBatch),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'items': logs
                  .map(
                    (log) => [
                      log.localId,
                      log.projectId,
                      log.kpisMet,
                      log.notes,
                      log.gpsLatitude?.toString() ?? '',
                      log.gpsLongitude?.toString() ?? '',
                      log.timestamp.toUtc().toIso8601String(),
                    ],
                  )
                  .toList(growable: false),
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const SyncUploadException(
        'The server took too long to respond. The records will retry.',
        isTransient: true,
      );
    } on SocketException {
      throw const SyncUploadException(
        'Unable to reach the server. The records will retry.',
        isTransient: true,
      );
    } on http.ClientException {
      throw const SyncUploadException(
        'Unable to reach the server. The records will retry.',
        isTransient: true,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SyncUploadException(
        _responseMessage(response),
        statusCode: response.statusCode,
        isTransient:
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const SyncUploadException(
        'The server returned an invalid sync response.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['synced_items'] is! List) {
      throw const SyncUploadException(
        'The server returned an invalid sync response.',
      );
    }

    final syncedItems = decoded['synced_items'] as List<dynamic>;
    final outcomes = <String, String?>{};
    for (final log in logs) {
      final matches = syncedItems
          .where(
            (item) =>
                item is Map<String, dynamic> && item['local_id'] == log.localId,
          )
          .toList(growable: false);
      if (matches.length != 1) {
        outcomes[log.localId] = matches.isEmpty
            ? 'The server did not return a sync result for this record.'
            : 'The server returned duplicate sync results for this record.';
        continue;
      }

      final result = matches.single as Map<String, dynamic>;
      if (result['status'] == 'success') {
        outcomes[log.localId] = null;
      } else {
        final itemMessage = result['message'] ?? result['error'];
        final status = result['status'];
        outcomes[log.localId] = itemMessage is String && itemMessage.isNotEmpty
            ? itemMessage
            : 'The server reported a sync failure'
                  '${status is String && status.isNotEmpty ? ' ($status)' : ''}.';
      }
    }
    return outcomes;
  }

  Future<void> _uploadFinancialTransaction(
    LocalFinancialTransaction transaction,
    String token,
  ) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(
              ApiConstants.projectFinancialTransactions(transaction.projectId),
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': '******',
            },
            body: jsonEncode({
              'objective_id': transaction.objectiveId,
              'amount': transaction.amount,
              'transaction_date': transaction.transactionDate
                  .toUtc()
                  .toIso8601String(),
              'remark': transaction.remark,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const SyncUploadException(
        'The server took too long to respond. The records will retry.',
        isTransient: true,
      );
    } on SocketException {
      throw const SyncUploadException(
        'Unable to reach the server. The records will retry.',
        isTransient: true,
      );
    } on http.ClientException {
      throw const SyncUploadException(
        'Unable to reach the server. The records will retry.',
        isTransient: true,
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw SyncUploadException(
      _responseMessage(response),
      statusCode: response.statusCode,
      isTransient:
          response.statusCode == 408 ||
          response.statusCode == 429 ||
          response.statusCode >= 500,
    );
  }

  Future<void> _uploadProjectUpdate(
    LocalProjectUpdate update,
    String token,
  ) async {
    if (!await File(update.filePath).exists()) {
      throw const SyncUploadException(
        'The attached file is no longer available on this device.',
      );
    }
    await _dashboardService.uploadProjectDocument(
      token: token,
      projectId: update.projectId,
      file: XFile(update.filePath),
      name: update.name,
      description: update.description,
    );
  }

  // Network failures surface as ApiException without a status code.
  bool _isTransientUploadError(Object error) {
    if (error is SyncUploadException) return error.isTransient;
    if (error is ApiException) {
      final status = error.statusCode;
      return status == null || status == 408 || status == 429 || status >= 500;
    }
    return false;
  }

  String _responseMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Upload failed (HTTP ${response.statusCode}).';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return 'Upload failed (HTTP ${response.statusCode}).';
    }
    return 'Upload failed (HTTP ${response.statusCode}).';
  }

  String _errorMessage(Object error) => error.toString();

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
