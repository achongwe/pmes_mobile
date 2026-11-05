/// API base URL and endpoint constants.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl =
      'https://0cae-105-234-179-228.ngrok-free.app/api/v1';

  static const String login = '$baseUrl/login';

  static const String logout = '$baseUrl/logout';

  static const String dashboardOverview = '$baseUrl/dashboard/overview';

  static const String syncBatch = '$baseUrl/sync/batch';

  static const String userProfile = '$baseUrl/me/profile';

  static const String notifications = '$baseUrl/me/notifications';

  static String projectGps(String projectId) =>
      '$baseUrl/projects/$projectId/gps';

  static String projectDocuments(String projectId) =>
      '$baseUrl/projects/$projectId/documents';

  static String projectKpis(String projectId) =>
      '$baseUrl/projects/$projectId/kpis';

  static String projectFinancialTransactions(String projectId) =>
      '$baseUrl/projects/$projectId/financial-transactions';
}
