import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/connectivity_provider.dart';
import '../../core/services/location_provider.dart';
import '../../core/services/session_provider.dart';
import '../../core/theme/app_colors.dart';

class FieldCommandCard extends StatefulWidget {
  const FieldCommandCard({super.key});

  @override
  State<FieldCommandCard> createState() => _FieldCommandCardState();
}

class _FieldCommandCardState extends State<FieldCommandCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<LocationProvider>().refreshLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightMode = colorScheme.brightness == Brightness.light;
    final foregroundColor = isLightMode ? Colors.white : colorScheme.onSurface;
    final mutedForegroundColor = isLightMode
        ? Colors.white.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;
    final userName = context.watch<SessionProvider>().userName;
    final locationProvider = context.watch<LocationProvider>();
    final connectivityProvider = context.watch<ConnectivityProvider>();

    final statusText = connectivityProvider.isChecking
        ? 'Checking...'
        : (connectivityProvider.isOnline ? 'Online' : 'Offline');
    final statusColor = connectivityProvider.isChecking
        ? mutedForegroundColor
        : (connectivityProvider.isOnline
              ? colorScheme.tertiary
              : colorScheme.error);

    final locationText =
        locationProvider.locationLabel ??
        (locationProvider.isLoading
            ? 'Detecting your current location...'
            : (locationProvider.errorMessage ?? 'Location unavailable'));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isLightMode ? AppColors.primaryLight : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FIELD OFFICER',
                style: TextStyle(
                  fontSize: 12,
                  color: mutedForegroundColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_problem,
                      color: colorScheme.onSecondaryContainer,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '3 Pending',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back,\n${userName?.isNotEmpty == true ? userName : 'Field Officer'}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: foregroundColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: mutedForegroundColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedForegroundColor, fontSize: 14),
                ),
              ),
              IconButton(
                tooltip: 'Refresh location',
                onPressed: locationProvider.isLoading
                    ? null
                    : () => context.read<LocationProvider>().refreshLocation(),
                icon: Icon(
                  Icons.refresh,
                  size: 18,
                  color: mutedForegroundColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _StatusIndicator(
                color: statusColor,
                text: statusText,
                foregroundColor: foregroundColor,
                backgroundColor: isLightMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : colorScheme.surface,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh internet status',
                onPressed: connectivityProvider.isChecking
                    ? null
                    : () =>
                          context.read<ConnectivityProvider>().refreshStatus(),
                icon: Icon(
                  Icons.wifi_tethering,
                  size: 18,
                  color: mutedForegroundColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.color,
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final Color color;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: foregroundColor, fontSize: 12)),
        ],
      ),
    );
  }
}
