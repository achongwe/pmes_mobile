/// API base URL and endpoint constants.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://pmes.optimumsystemsmw.com/api/v1';

  static const String login = '$baseUrl/login';

  static const String logout = '$baseUrl/logout';

  static const String dashboardOverview = '$baseUrl/dashboard/overview';

  static const String syncBatch = '$baseUrl/sync/batch';

  static const String userProfile = '$baseUrl/me/profile';

  static const String notifications = '$baseUrl/me/notifications';
  static const String markAllNotificationsRead =
      '$baseUrl/me/notifications/read-all';

  static String projectGps(String projectId) =>
      '$baseUrl/projects/$projectId/gps';

  static String projectDocuments(String projectId) =>
      '$baseUrl/projects/$projectId/documents';

  static String projectKpis(String projectId) =>
      '$baseUrl/projects/$projectId/kpis';

  static String kpi(String kpiId) => '$baseUrl/kpis/$kpiId';

  static String projectFinancialTransactions(String projectId) =>
      '$baseUrl/projects/$projectId/financial-transactions';
}
