import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pmes_mobile/core/services/api_exception.dart';
import 'package:pmes_mobile/core/services/notifications_service.dart';

void main() {
  test('loads notifications and pagination metadata', () async {
    final service = NotificationsService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/api/v1/me/notifications'));
        expect(request.url.queryParameters['page'], '2');
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['authorization'], 'Bearer notifications-token');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'notifications': [
                {
                  'id': 'notification-1',
                  'type': 'project_update',
                  'data': {
                    'title': 'Project updated',
                    'message': 'A project has a new status.',
                  },
                  'read_at': null,
                  'created_at': '2026-10-29T14:00:00Z',
                },
              ],
              'unread_count': 3,
            },
            'meta': {
              'current_page': 2,
              'last_page': 4,
              'per_page': 10,
              'total': 34,
            },
          }),
          200,
        );
      }),
    );

    final response = await service.getNotifications(
      token: 'notifications-token',
      page: 2,
    );

    expect(response.notifications, hasLength(1));
    expect(response.notifications.single.title, 'Project updated');
    expect(
      response.notifications.single.message,
      'A project has a new status.',
    );
    expect(response.notifications.single.isUnread, isTrue);
    expect(response.unreadCount, 3);
    expect(response.currentPage, 2);
    expect(response.lastPage, 4);
    expect(response.perPage, 10);
    expect(response.total, 34);
  });

  test(
    'uses safe defaults for unknown and dynamic notification data',
    () async {
      final service = NotificationsService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'notifications': [
                  {
                    'id': 42,
                    'type': 'Vendor\\Notifications\\New_Alert',
                    'data': [
                      null,
                      {'content': 'unrecognized payload'},
                    ],
                    'read_at': 'not-a-date',
                    'created_at': 'not-a-date',
                  },
                  null,
                ],
                'unread_count': 0,
              },
              'meta': {
                'current_page': 1,
                'last_page': 1,
                'per_page': 10,
                'total': 1,
              },
            }),
            200,
          ),
        ),
      );

      final response = await service.getNotifications(token: 'token');
      final notification = response.notifications.single;
      expect(notification.id, '42');
      expect(notification.title, 'New Alert');
      expect(notification.message, 'You have a new update.');
      expect(notification.isUnread, isTrue);
      expect(notification.createdAt, isNull);
    },
  );

  test(
    'marks all notifications as read and returns the unread count',
    () async {
      final service = NotificationsService(
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(
            request.url.path,
            endsWith('/api/v1/me/notifications/read-all'),
          );
          expect(request.headers['accept'], 'application/json');
          expect(request.headers['authorization'], 'Bearer read-all-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'All notifications marked as read.',
              'data': {'unread_count': 0},
            }),
            200,
          );
        }),
      );

      expect(await service.markAllAsRead(token: 'read-all-token'), 0);
    },
  );

  test('mark all as read surfaces unauthorized responses', () async {
    final service = NotificationsService(
      client: MockClient(
        (_) async => http.Response('{"message":"Unauthenticated."}', 401),
      ),
    );

    await expectLater(
      service.markAllAsRead(token: 'expired-token'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('returns an authentication error for unauthorized responses', () async {
    final service = NotificationsService(
      client: MockClient(
        (_) async => http.Response('{"message":"Unauthenticated."}', 401),
      ),
    );

    await expectLater(
      service.getNotifications(token: 'expired-token'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'Your session has expired. Please sign in again.',
            ),
      ),
    );
  });
}
