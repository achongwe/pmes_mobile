import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../core/models/dashboard_overview.dart';
import '../core/models/user_profile.dart';
import '../core/services/api_exception.dart';
import '../core/services/auth_service.dart';
import '../core/services/dashboard_service.dart';
import '../core/services/session_provider.dart';
import '../core/services/user_profile_service.dart';
import '../core/theme/app_colors.dart';
import 'profile_page.dart';
import 'appearance_settings_page.dart';
import 'sync_queue_page.dart';
import '../widgets/home/assigned_project_card.dart';
import '../widgets/home/assigned_projects_header.dart';
import '../widgets/home/custom_bottom_nav_bar.dart';
import '../widgets/home/field_command_card.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_stat_card.dart';
import '../widgets/home/kpi_summary_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _authService = AuthService();
  static const _dashboardService = DashboardService();
  static const _profileService = UserProfileService();
  bool _isLoggingOut = false;
  bool _isAppearanceOpen = false;
  int _selectedTab = 0;

  DashboardOverviewData? _overview;
  ProfileUser? _profile;
  bool _isProfileLoading = false;
  String? _profileError;
  bool _isInitialLoading = true;
  String? _initialErrorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_overview == null && _isInitialLoading) {
      _loadInitialOverview();
    }
  }

  Future<DashboardOverviewData> _loadOverview() async {
    final token = context.read<SessionProvider>().token;
    if (token == null) {
      throw const ApiException('You are not signed in.');
    }
    final response = await _dashboardService.getOverview(token: token);
    return response.data;
  }

  Future<void> _loadInitialOverview() async {
    setState(() {
      _isInitialLoading = true;
      _initialErrorMessage = null;
    });
    final profileLoad = _loadInitialProfile();
    try {
      final overview = await _loadOverview();
      await profileLoad;
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Something went wrong while loading the dashboard.';
      setState(() {
        _initialErrorMessage = message;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadInitialProfile() async {
    if (_profile != null) return;
    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });
    try {
      final token = context.read<SessionProvider>().token;
      if (token == null) {
        throw const ApiException('You are not signed in.');
      }
      final response = await _profileService.getProfile(token: token);
      if (!mounted) return;
      setState(() {
        _profile = response.user;
        _isProfileLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error is ApiException
            ? error.message
            : 'Something went wrong while loading your profile.';
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final overview = await _loadOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _initialErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Something went wrong while refreshing the dashboard.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionProvider>();
    final token = session.token;
    String? serverLogoutError;
    try {
      if (token != null) {
        try {
          await _authService.logout(token: token);
        } catch (error) {
          serverLogoutError = error is ApiException
              ? error.message
              : 'The server could not confirm the logout.';
        }
      }
      await session.signOut();
      if (!mounted) return;
      context.go('/login');
      if (serverLogoutError != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'You were signed out on this device. $serverLogoutError',
              ),
            ),
          );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Unable to clear the local session. Please try again.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will be signed out of your PMES account on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) {
      await _handleLogout();
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedTab = index;
      _isAppearanceOpen = false;
    });
  }

  Future<void> _openNewUpdate() async {
    final projects = _overview?.projects ?? [];
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No assigned projects are available.')),
        );
      return;
    }

    final uploaded = await context.pushNamed<bool>(
      'project-document-upload',
      extra: projects,
    );
    if (!mounted || uploaded != true) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isAppearanceOpen
          ? AppBar(
              leading: IconButton(
                onPressed: () => setState(() => _isAppearanceOpen = false),
                tooltip: 'Back to Profile',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: const Text('Appearance'),
            )
          : const HomeAppBar(),
      bottomNavigationBar: CustomBottomNavBar(
        onNewUpdate: _openNewUpdate,
        selectedIndex: _selectedTab,
        onDestinationSelected: _onDestinationSelected,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedTab == 3) {
      if (_isAppearanceOpen) {
        return const AppearanceSettingsPage();
      }
      if (_isProfileLoading) {
        return const _HomePageLoadingShimmer();
      }
      final session = context.watch<SessionProvider>();
      return ProfilePage(
        token: session.token,
        userName: session.userName,
        userEmail: session.userEmail,
        lastLogin: session.lastLogin,
        overview: _overview,
        initialProfile: _profile,
        initialProfileError: _profileError,
        onLogout: _confirmLogout,
        onAppearance: () => setState(() => _isAppearanceOpen = true),
        onProfileLoaded: (profile) {
          setState(() {
            _profile = profile;
            _profileError = null;
          });
        },
        onProfileLoadError: (message) {
          setState(() => _profileError = message);
        },
        onProfileUpdated: (profile) async {
          setState(() {
            _profile = profile;
            _profileError = null;
          });
          await session.updateUserProfile(
            profile.displayName ?? session.userName ?? '',
            profile.email ?? session.userEmail ?? '',
          );
        },
      );
    }

    if (_selectedTab == 2) {
      return const SyncQueuePage();
    }

    if (_isInitialLoading) {
      return const _HomePageLoadingShimmer();
    }

    if (_overview == null) {
      return _ErrorState(
        message:
            _initialErrorMessage ??
            'Something went wrong while loading the dashboard.',
        onRetry: _loadInitialOverview,
      );
    }

    final overview = _overview!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top Field Command Dark Card ---
            const FieldCommandCard(),
            const SizedBox(height: 16),

            // --- Stats Row (Assigned Projects & Fiscal Allocation) ---
            Row(
              children: [
                Expanded(
                  child: HomeStatCard(
                    icon: Icons.folder_outlined,
                    value: overview.summary.assignedProjects.count,
                    label: 'Assigned Projects',
                    subLabel: overview.summary.assignedProjects.description,
                    rightWidget: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        overview.summary.assignedProjects.statusLabel,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HomeStatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    value: overview.summary.fiscalAllocation.formattedAmount,
                    label: overview.summary.fiscalAllocation.currency,
                    subLabel:
                        'Budgets',
                    rightWidget:
                        overview.summary.fiscalAllocation.percentageChange ==
                            null
                        ? null
                        : Text(
                            '${overview.summary.fiscalAllocation.percentageChange! >= 0 ? '+' : ''}${overview.summary.fiscalAllocation.percentageChange}%',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            KpiSummaryCard(
              verified: overview.summary.kpiOverview.verified,
              total: overview.summary.kpiOverview.total,
              completionPercentage:
                  overview.summary.kpiOverview.completionPercentage,
              nextReviewLabel: overview.summary.kpiOverview.nextReviewLabel,
            ),
            const SizedBox(height: 28),

            AssignedProjectsHeader(activeCount: overview.projects.length),
            const SizedBox(height: 16),

            if (overview.projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No assigned projects yet.',
                  style: TextStyle(color: AppColors.neutral),
                ),
              )
            else
              for (final project in overview.projects) ...[
                AssignedProjectCard(project: project, onDataChanged: _refresh),
                const SizedBox(height: 16),
              ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _HomePageLoadingShimmer extends StatelessWidget {
  const _HomePageLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Shimmer.fromColors(
        baseColor: AppColors.neutralLight.withValues(alpha: 0.7),
        highlightColor: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerBox(height: 206, borderRadius: 24),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _ShimmerStatCard()),
                SizedBox(width: 12),
                Expanded(child: _ShimmerStatCard()),
              ],
            ),
            SizedBox(height: 12),
            _ShimmerBox(height: 90, borderRadius: 20),
            SizedBox(height: 28),
            _ShimmerProjectsHeader(),
            SizedBox(height: 16),
            _ShimmerProjectCard(),
            SizedBox(height: 16),
            _ShimmerProjectCard(),
            SizedBox(height: 16),
            _ShimmerBox(height: 56, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

class _ShimmerStatCard extends StatelessWidget {
  const _ShimmerStatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBox(height: 40, width: 40, borderRadius: 10),
              _ShimmerBox(height: 20, width: 70, borderRadius: 10),
            ],
          ),
          SizedBox(height: 24),
          _ShimmerBox(height: 24, width: 90, borderRadius: 8),
          SizedBox(height: 8),
          _ShimmerBox(height: 14, width: 110, borderRadius: 8),
          SizedBox(height: 6),
          _ShimmerBox(height: 12, width: 80, borderRadius: 8),
        ],
      ),
    );
  }
}

class _ShimmerProjectsHeader extends StatelessWidget {
  const _ShimmerProjectsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _ShimmerBox(height: 20, width: 180, borderRadius: 8),
            SizedBox(width: 8),
            _ShimmerBox(height: 24, width: 70, borderRadius: 16),
          ],
        ),
        _ShimmerBox(height: 34, width: 34, borderRadius: 10),
      ],
    );
  }
}

class _ShimmerProjectCard extends StatelessWidget {
  const _ShimmerProjectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ShimmerBox(height: 12, width: 130, borderRadius: 6),
              Row(
                children: [
                  _ShimmerBox(height: 22, width: 54, borderRadius: 10),
                  SizedBox(width: 6),
                  _ShimmerBox(height: 22, width: 54, borderRadius: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          _ShimmerBox(height: 18, width: double.infinity, borderRadius: 8),
          SizedBox(height: 8),
          _ShimmerBox(height: 12, width: double.infinity, borderRadius: 8),
          SizedBox(height: 6),
          _ShimmerBox(height: 12, width: 220, borderRadius: 8),
          SizedBox(height: 16),
          _ShimmerBox(height: 58, borderRadius: 12),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ShimmerBox(height: 72, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: _ShimmerBox(height: 72, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: _ShimmerBox(height: 72, borderRadius: 12)),
            ],
          ),
          SizedBox(height: 14),
          _ShimmerBox(height: 74, borderRadius: 16),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ShimmerBox(height: 44, borderRadius: 12)),
              SizedBox(width: 10),
              Expanded(child: _ShimmerBox(height: 44, borderRadius: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.height,
    this.width,
    required this.borderRadius,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.neutral, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
