import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/models/notification.dart';
import '../core/services/api_exception.dart';
import '../core/services/notifications_service.dart';
import '../core/services/session_provider.dart';
import '../core/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _service = NotificationsService();
  final _scrollController = ScrollController();
  final List<AppNotification> _notifications = [];

  bool _hasStarted = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isMarkingAllRead = false;
  String? _errorMessage;
  String? _paginationError;
  int _unreadCount = 0;
  int _currentPage = 0;
  int _lastPage = 1;

  bool get _hasMore => _currentPage < _lastPage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _loadNotifications();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoading &&
        _paginationError == null) {
      _loadNextPage();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _paginationError = null;
      _notifications.clear();
      _currentPage = 0;
      _lastPage = 1;
    });
    await _loadPage(1);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });
    await _loadPage(_currentPage + 1, isNextPage: true);
  }

  Future<void> _loadPage(int page, {bool isNextPage = false}) async {
    try {
      final token = context.read<SessionProvider>().token;
      if (token == null) {
        throw const ApiException('You are not signed in.');
      }
      final response = await _service.getNotifications(
        token: token,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (isNextPage) {
          final existingIds = _notifications.map((item) => item.id).toSet();
          _notifications.addAll(
            response.notifications.where(
              (item) => item.id.isEmpty || !existingIds.contains(item.id),
            ),
          );
        } else {
          _notifications
            ..clear()
            ..addAll(response.notifications);
        }
        _unreadCount = response.unreadCount;
        _currentPage = response.currentPage > 0 ? response.currentPage : page;
        _lastPage = response.lastPage;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
        _paginationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Something went wrong while loading notifications.';
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (isNextPage) {
          _paginationError = message;
        } else {
          _errorMessage = message;
        }
      });
      if (error is ApiException && error.statusCode == 401) {
        try {
          await context.read<SessionProvider>().signOut();
          if (mounted) context.go('/login');
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Your session expired, but this device could not clear it. Please try again.';
          });
        }
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead || _unreadCount == 0) return;
    setState(() => _isMarkingAllRead = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = context.read<SessionProvider>().token;
      if (token == null) {
        throw const ApiException('You are not signed in.');
      }
      final unreadCount = await _service.markAllAsRead(token: token);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _unreadCount = unreadCount;
        for (var i = 0; i < _notifications.length; i++) {
          final item = _notifications[i];
          if (item.isUnread) {
            _notifications[i] = AppNotification(
              id: item.id,
              type: item.type,
              title: item.title,
              message: item.message,
              readAt: now,
              createdAt: item.createdAt,
            );
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Could not mark notifications as read.',
          ),
        ),
      );
      if (error is ApiException && error.statusCode == 401) {
        try {
          await context.read<SessionProvider>().signOut();
          if (mounted) context.go('/login');
        } catch (_) {
          // The snackbar already explains the expired session.
        }
      }
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_unreadCount > 0)
            _isMarkingAllRead
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Mark all as read',
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all_rounded),
                  ),
        ],
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 10),
              _UnreadCountBadge(count: _unreadCount),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const _NotificationsLoadingShimmer()
          : _errorMessage != null && _notifications.isEmpty
          ? _NotificationsError(
              message: _errorMessage!,
              onRetry: _loadNotifications,
            )
          : _notifications.isEmpty
          ? const _NotificationsEmpty()
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount:
                    _notifications.length +
                    (_isLoadingMore || _paginationError != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    if (_paginationError != null) {
                      return _PaginationRetry(
                        message: _paginationError!,
                        onRetry: _loadNextPage,
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                        ),
                      ),
                    );
                  }
                  final notification = _notifications[index];
                  return _NotificationCard(notification: notification);
                },
              ),
            ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _NotificationsLoadingShimmer extends StatelessWidget {
  const _NotificationsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = AppColors.neutralLight.withValues(alpha: 0.45);
    final highlightColor = theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 112,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 11,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      width: 150,
                      height: 11,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _notificationIcon(notification.type);
    return Card(
      margin: EdgeInsets.zero,
      color: notification.isUnread
          ? theme.colorScheme.surface
          : theme.colorScheme.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: notification.isUnread
            ? BorderSide(color: AppColors.secondary.withValues(alpha: 0.22))
            : BorderSide(color: theme.dividerColor.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.isUnread) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('project')) return Icons.folder_open_outlined;
    if (normalized.contains('budget') || normalized.contains('payment')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (normalized.contains('document') || normalized.contains('file')) {
      return Icons.description_outlined;
    }
    if (normalized.contains('kpi') || normalized.contains('progress')) {
      return Icons.insert_chart_outlined_rounded;
    }
    if (normalized.contains('user') || normalized.contains('account')) {
      return Icons.person_outline_rounded;
    }
    return Icons.notifications_none_rounded;
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return 'Recently';
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.isNegative || difference.inMinutes == 0) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'You’re all caught up',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New notifications will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.neutral,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationRetry extends StatelessWidget {
  const _PaginationRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry loading more'),
          ),
        ],
      ),
    );
  }
}
