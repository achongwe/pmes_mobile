import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/api_constants.dart';
import '../models/dashboard_overview.dart';
import 'api_exception.dart';

class DashboardService {
  const DashboardService();

  static const Duration _timeout = Duration(seconds: 15);

  Future<DashboardOverviewResponse> getOverview({required String token}) async {
    final Uri uri = Uri.parse(ApiConstants.dashboardOverview);

    late final http.Response response;
    try {
      response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Unable to reach the server. Check your connection.',
      );
    }

    final Map<String, dynamic> body = response.body.isEmpty
        ? {}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return DashboardOverviewResponse.fromJson(body);
    }

    throw ApiException(
      body['message'] as String? ?? 'Failed to load dashboard overview.',
      statusCode: response.statusCode,
    );
  }

  Future<void> updateProjectGps({
    required String token,
    required String projectId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final Uri uri = Uri.parse(ApiConstants.projectGps(projectId));

    late final http.Response response;
    try {
      response = await http
          .put(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'accuracy': accuracy,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Unable to reach the server. Check your connection.',
      );
    }

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 202 ||
        response.statusCode == 204) {
      return;
    }

    final Map<String, dynamic> body = response.body.isEmpty
        ? {}
        : jsonDecode(response.body) as Map<String, dynamic>;
    throw ApiException(
      body['message'] as String? ?? 'Failed to update project GPS coordinates.',
      statusCode: response.statusCode,
    );
  }

  /// Creates a KPI for a project and returns the server's success message.
  Future<String> createProjectKpi({
    required String token,
    required String projectId,
    String? objectiveId,
    required String name,
    required num baselineValue,
    required num targetValue,
    required String aggregationMethod,
    required String reportingPeriod,
    required String description,
  }) {
    return _postJson(
      token: token,
      url: ApiConstants.projectKpis(projectId),
      payload: {
        'objective_id': objectiveId,
        'name': name,
        'baseline_value': baselineValue,
        'target_value': targetValue,
        'aggregation_method': aggregationMethod,
        'reporting_period': reportingPeriod,
        'description': description,
      },
      successMessage: 'KPI created successfully.',
      failureMessage: 'Failed to create the KPI',
    );
  }

  /// Updates an existing KPI (PUT /kpis/{kpi}) and returns the server's
  /// success message.
  Future<String> updateKpi({
    required String token,
    required String kpiId,
    String? objectiveId,
    required String name,
    required num baselineValue,
    required num targetValue,
    required String aggregationMethod,
    required String reportingPeriod,
    required String description,
  }) {
    return _postJson(
      method: 'PUT',
      token: token,
      url: ApiConstants.kpi(kpiId),
      payload: {
        'objective_id': objectiveId == null ? null : int.tryParse(objectiveId),
        'name': name,
        'baseline_value': baselineValue,
        'target_value': targetValue,
        'aggregation_method': aggregationMethod,
        'reporting_period': reportingPeriod,
        'description': description,
      },
      successMessage: 'KPI updated successfully.',
      failureMessage: 'Failed to update the KPI',
    );
  }

  /// Records a financial expenditure and returns the server's success message.
  Future<String> recordFinancialTransaction({
    required String token,
    required String projectId,
    String? objectiveId,
    required num amount,
    required String transactionDate,
    required String remark,
  }) {
    return _postJson(
      token: token,
      url: ApiConstants.projectFinancialTransactions(projectId),
      payload: {
        'objective_id': objectiveId,
        'amount': amount,
        'transaction_date': transactionDate,
        'remark': remark,
      },
      successMessage: 'Financial expenditure successfully recorded.',
      failureMessage: 'Failed to record the financial expenditure',
    );
  }

  /// Records KPI monitoring data for a KPI and returns the server's success
  /// message.
  Future<String> recordKpiMonitoringData({
    required String token,
    required String kpiId,
    required num achievedValue,
    required String reportingDate,
  }) {
    return _postJson(
      token: token,
      url: ApiConstants.kpiData(kpiId),
      payload: {
        'achieved_value': achievedValue,
        'reporting_date': reportingDate,
      },
      successMessage: 'KPI monitoring data recorded successfully.',
      failureMessage: 'Failed to record KPI monitoring data',
    );
  }

  Future<String> _postJson({
    required String token,
    required String url,
    required Map<String, dynamic> payload,
    required String successMessage,
    required String failureMessage,
    String method = 'POST',
  }) async {
    late final http.Response response;
    try {
      final request = http.Request(method, Uri.parse(url))
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode(payload);
      response = await http.Response.fromStream(
        await request.send().timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Unable to reach the server. Check your connection.',
      );
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = response.body.isEmpty ? {} : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Fall through to the status-based error below.
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      return body['message'] as String? ?? successMessage;
    }

    String? validationMessage;
    final validationErrors = body['errors'];
    if (validationErrors is Map) {
      for (final errors in validationErrors.values) {
        if (errors is List && errors.isNotEmpty) {
          validationMessage = errors.first.toString();
          break;
        }
      }
    }
    throw ApiException(
      validationMessage ??
          body['message'] as String? ??
          '$failureMessage (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<void> uploadProjectDocument({
    required String token,
    required String projectId,
    required XFile file,
    required String name,
    required String description,
  }) async {
    if (name.trim().isEmpty || description.trim().isEmpty) {
      throw const ApiException('Name and description are required.');
    }
    if (name.length > 255 || description.length > 500) {
      throw const ApiException(
        'The document name or description exceeds the allowed length.',
      );
    }

    final int fileSize;
    try {
      fileSize = await File(file.path).length();
    } on FileSystemException {
      throw const ApiException('Unable to read the selected file.');
    }
    if (fileSize > 5120 * 1024) {
      throw const ApiException('The selected file must be 5 MB or smaller.');
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(ApiConstants.projectDocuments(projectId)),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['name'] = name
          ..fields['description'] = description;
    request.headers['Authorization'] = 'Bearer $token';
    late final http.Response response;
    try {
      request.files.add(
        await http.MultipartFile.fromPath('document_file', file.path),
      );
      final streamedResponse = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamedResponse)
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Unable to reach the server. Check your connection.',
      );
    } on FileSystemException {
      throw const ApiException('Unable to read the selected file.');
    }

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    }

    final Map<String, dynamic> body;
    try {
      final decoded = response.body.isEmpty ? {} : jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      throw ApiException(
        'Failed to upload the document (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    final validationErrors = body['errors'];
    String? validationMessage;
    if (validationErrors is Map) {
      for (final errors in validationErrors.values) {
        if (errors is List && errors.isNotEmpty) {
          validationMessage = errors.first.toString();
          break;
        }
      }
    }
    throw ApiException(
      validationMessage ??
          body['message'] as String? ??
          'Failed to upload the document.',
      statusCode: response.statusCode,
    );
  }
}
