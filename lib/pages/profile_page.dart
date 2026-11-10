import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/dashboard_overview.dart';
import '../core/models/user_profile.dart';
import '../core/services/api_exception.dart';
import '../core/services/user_profile_service.dart';
import '../core/theme/app_colors.dart';
import 'basic_information_page.dart';
import 'account_security_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.userName,
    required this.userEmail,
    required this.overview,
    required this.onLogout,
    this.token,
    this.lastLogin,
    this.onAppearance,
    this.onProfileUpdated,
    this.onProfileLoaded,
    this.onProfileLoadError,
    this.initialProfile,
    this.initialProfileError,
    this.profileService = const UserProfileService(),
    super.key,
  });

  final String? userName;
  final String? userEmail;
  final DashboardOverviewData? overview;
  final VoidCallback onLogout;
  final String? token;
  final DateTime? lastLogin;
  final VoidCallback? onAppearance;
  final Future<void> Function(ProfileUser)? onProfileUpdated;
  final ValueChanged<ProfileUser>? onProfileLoaded;
  final ValueChanged<String>? onProfileLoadError;
  final ProfileUser? initialProfile;
  final String? initialProfileError;
  final UserProfileService profileService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _profilePhotoKey = 'profile_photo_path';
  final ImagePicker _imagePicker = ImagePicker();
  String? _profilePhotoPath;
  bool _isPickingPhoto = false;
  bool _isLoadingProfile = false;
  String? _profileError;
  ProfileUser? _profile;
  int _profileRequestId = 0;

  Future<void> _handleProfileUpdated(ProfileUser updatedProfile) async {
    if (!mounted) return;
    setState(() => _profile = updatedProfile);
    await widget.onProfileUpdated?.call(updatedProfile);
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _profileError = widget.initialProfileError;
    _loadProfilePhoto();
    if (_profile == null && _profileError == null) {
      _loadProfile();
    }
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token ||
        oldWidget.profileService != widget.profileService) {
      if (widget.initialProfile != null) {
        setState(() {
          _profile = widget.initialProfile;
          _profileError = widget.initialProfileError;
          _isLoadingProfile = false;
        });
      } else {
        _loadProfile();
      }
    } else if (oldWidget.initialProfile != widget.initialProfile ||
        oldWidget.initialProfileError != widget.initialProfileError) {
      setState(() {
        _profile = widget.initialProfile;
        _profileError = widget.initialProfileError;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final requestId = ++_profileRequestId;
    final token = widget.token;
    if (token == null || token.isEmpty) {
      if (_profile != null || _profileError != null || _isLoadingProfile) {
        setState(() {
          _profile = null;
          _profileError = null;
          _isLoadingProfile = false;
        });
      }
      return;
    }
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });
    try {
      final response = await widget.profileService.getProfile(token: token);
      if (!mounted || requestId != _profileRequestId) return;
      setState(() {
        _profile = response.user;
        _isLoadingProfile = false;
      });
      widget.onProfileLoaded?.call(response.user);
    } catch (error) {
      if (!mounted || requestId != _profileRequestId) return;
      final message = error is ApiException
          ? error.message
          : 'Something went wrong while loading your profile.';
      setState(() {
        _profileError = message;
        _isLoadingProfile = false;
      });
      widget.onProfileLoadError?.call(message);
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedPath = preferences.getString(_profilePhotoKey);
      if (savedPath == null) return;
      if (!await File(savedPath).exists()) {
        await preferences.remove(_profilePhotoKey);
        return;
      }
      if (mounted) setState(() => _profilePhotoPath = savedPath);
    } on Exception {
      if (mounted) {
        _showPhotoMessage('Unable to load your saved profile photo.');
      }
    }
  }

  Future<void> _chooseProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _isPickingPhoto = true);
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;

      final appDirectory = await getApplicationDocumentsDirectory();
      final extension = _imageExtension(image.name);
      final destination = File(
        '${appDirectory.path}${Platform.pathSeparator}profile_photo.$extension',
      );
      await File(image.path).copy(destination.path);

      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _profilePhotoKey,
        destination.path,
      );
      if (!saved) {
        throw const FileSystemException('Could not save profile photo path.');
      }
      if (mounted) {
        setState(() => _profilePhotoPath = destination.path);
      }
    } on PlatformException {
      if (mounted) {
        _showPhotoMessage('Unable to access the selected photo.');
      }
    } on FileSystemException {
      if (mounted) _showPhotoMessage('Unable to save the profile photo.');
    } on Exception {
      if (mounted) _showPhotoMessage('Unable to update the profile photo.');
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  String _imageExtension(String name) {
    final separator = name.lastIndexOf('.');
    if (separator == -1 || separator == name.length - 1) return 'jpg';
    final extension = name.substring(separator + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]+$').hasMatch(extension) ? extension : 'jpg';
  }

  void _showPhotoMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBasicInformation({
    required String name,
    required String email,
    required String departmentName,
    required ProfileDepartment? department,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BasicInformationPage(
          userName: name,
          userEmail: _profile?.email ?? email,
          profilePhotoPath: _profilePhotoPath,
          token: widget.token,
          profileService: widget.profileService,
          onProfileUpdated: _handleProfileUpdated,
          organization: departmentName,
          department: department?.code ?? departmentName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileName = _profile?.displayName;
    final name = profileName?.isNotEmpty == true
        ? profileName!
        : widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : 'Name unavailable';
    final profileEmail = _profile?.email;
    final email = profileEmail?.isNotEmpty == true
        ? profileEmail!
        : widget.userEmail?.trim().isNotEmpty == true
        ? widget.userEmail!.trim()
        : 'Email unavailable';
    final department = _profile?.department;
    final departmentName = department?.name ?? 'Department unavailable';
    final roles = _profile?.roleNames ?? const <String>[];
    final roleDescription = roles.join(', ');
    final lastLogin = _profile?.lastLogin ?? widget.lastLogin;
    final organizationDescription = [
      if (roleDescription.isNotEmpty) roleDescription,
      if (departmentName != 'Department unavailable') departmentName,
    ].join(' • ');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileIdentityCard(
            name: name,
            email: email,
            accountLabel: roles.isNotEmpty
                ? roleDescription
                : _profile?.accountStatus ?? 'PMES Account',
            profilePhotoPath: _profilePhotoPath,
            onEdit: () => _openBasicInformation(
              name: name,
              email: email,
              departmentName: departmentName,
              department: department,
            ),
            onChangePhoto: _isPickingPhoto ? null : _chooseProfilePhoto,
          ),
          if (_isLoadingProfile) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_profileError != null) ...[
            const SizedBox(height: 12),
            _ProfileLoadError(message: _profileError!, onRetry: _loadProfile),
          ],
          const SizedBox(height: 24),
          _ProfileSectionCard(
            title: 'PERSONAL INFORMATION',
            tiles: [
              _ProfileMenuTileData(
                icon: Icons.person_outline_rounded,
                title: 'Basic Information',
                description: 'Name, email, phone, location',
                onTap: () => _openBasicInformation(
                  name: name,
                  email: email,
                  departmentName: departmentName,
                  department: department,
                ),
              ),
              _ProfileMenuTileData(
                icon: Icons.shield_outlined,
                title: 'Account Security',
                description: 'Password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountSecurityPage(
                      userName: name,
                      userEmail: _profile?.email ?? widget.userEmail,
                      lastLogin: lastLogin,
                      firstName: _profile?.firstName,
                      lastName: _profile?.lastName,
                      token: widget.token,
                      profileService: widget.profileService,
                      onProfileUpdated: (updatedProfile) {
                        setState(() => _profile = updatedProfile);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileSectionCard(
            title: 'DEPARTMENT',
            tiles: [
              _ProfileMenuTileData(
                icon: Icons.business_outlined,
                title: 'My Department',
                description: organizationDescription.isEmpty
                    ? 'Role, department, team'
                    : organizationDescription,
                onTap: () => _showOrganizationDetails(_profile),
              ),
              _ProfileMenuTileData(
                icon: Icons.groups_outlined,
                title: 'Team Members',
                description: department == null
                    ? 'Team members are unavailable'
                    : '${department.colleagues.length} team members',
                onTap: () => _showTeamMembers(_profile),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileSectionCard(
            title: 'PREFERENCES',
            tiles: [
              _ProfileMenuTileData(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                description: 'Theme',
                onTap:
                    widget.onAppearance ??
                    () => _showUnavailableFeature(
                      context,
                      'Appearance settings are not available yet.',
                    ),
              ),
              _ProfileMenuTileData(
                icon: Icons.logout_rounded,
                title: 'Log Out',
                description: 'Sign out of your account',
                showChevron: false,
                onTap: widget.onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUnavailableFeature(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showOrganizationDetails(ProfileUser? profile) async {
    if (profile == null) {
      _showUnavailableFeature(context, 'Organization details are unavailable.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OrganizationDetailsSheet(profile: profile),
    );
  }

  Future<void> _showTeamMembers(ProfileUser? profile) async {
    final department = profile?.department;
    if (department == null) {
      _showUnavailableFeature(context, 'Team details are unavailable.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TeamMembersSheet(department: department),
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.name,
    required this.email,
    required this.accountLabel,
    required this.profilePhotoPath,
    required this.onEdit,
    required this.onChangePhoto,
  });

  final String name;
  final String email;
  final String accountLabel;
  final String? profilePhotoPath;
  final VoidCallback onEdit;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProfileAvatar(
            profilePhotoPath: profilePhotoPath,
            onChangePhoto: onChangePhoto,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.card,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Edit profile',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.card,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: AppColors.card.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    accountLabel,
                    style: TextStyle(
                      color: AppColors.card,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _OrganizationDetailsSheet extends StatelessWidget {
  const _OrganizationDetailsSheet({required this.profile});

  final ProfileUser profile;

  @override
  Widget build(BuildContext context) {
    final department = profile.department;
    final head = department?.headOfDepartment;
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'Organization details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _ProfileDetailRow(
            label: 'Account status',
            value: _profileValue(profile.accountStatus),
          ),
          _ProfileDetailRow(
            label: 'Department',
            value: _profileValue(department?.name),
          ),
          _ProfileDetailRow(
            label: 'Department code',
            value: _profileValue(department?.code),
          ),
          _ProfileDetailRow(
            label: 'Department description',
            value: _profileValue(department?.description),
          ),
          if (head != null) ...[
            const SizedBox(height: 8),
            Text(
              'Head of department',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _ProfileDetailRow(
              label: 'Name',
              value: _profileValue(head.fullName),
            ),
            _ProfileDetailRow(label: 'Email', value: _profileValue(head.email)),
          ],
        ],
      ),
    );
  }
}

class _TeamMembersSheet extends StatelessWidget {
  const _TeamMembersSheet({required this.department});

  final ProfileDepartment department;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              department.name == null
                  ? 'Team members'
                  : 'Team members • ${department.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: department.colleagues.isEmpty
                ? const Center(child: Text('No team members are listed.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: department.colleagues.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = department.colleagues[index];
                      final roleNames = person.roles
                          .map((role) => role.name)
                          .whereType<String>()
                          .where((role) => role.isNotEmpty)
                          .join(', ');
                      final contactDetails = [
                        if (person.email?.isNotEmpty == true) person.email,
                        if (roleNames.isNotEmpty) roleNames,
                      ].join(' • ');
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(_profileValue(person.fullName)),
                        subtitle: Text(
                          contactDetails.isEmpty
                              ? 'Contact details unavailable'
                              : contactDetails,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _profileValue(String? value) =>
    value?.trim().isNotEmpty == true ? value!.trim() : 'Not provided';

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profilePhotoPath,
    required this.onChangePhoto,
  });

  final String? profilePhotoPath;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0FF),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: profilePhotoPath == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.secondary,
                      size: 54,
                    )
                  : Image.file(
                      File(profilePhotoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        color: AppColors.secondary,
                        size: 54,
                      ),
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: AppColors.secondary,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onChangePhoto,
                tooltip: 'Change profile photo',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.card,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.tiles});

  final String title;
  final List<_ProfileMenuTileData> tiles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.68)
                    : AppColors.neutral,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          for (var index = 0; index < tiles.length; index++) ...[
            _ProfileMenuTile(data: tiles[index]),
            if (index < tiles.length - 1)
              Divider(
                height: 1,
                indent: 54,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuTileData {
  const _ProfileMenuTileData({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool showChevron;
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.data});

  final _ProfileMenuTileData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '${data.title}, ${data.description}',
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: AppColors.secondary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        color: isDark
                            ? colorScheme.onSurface
                            : AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.description,
                      style: TextStyle(
                        color: isDark
                            ? colorScheme.onSurface.withValues(alpha: 0.68)
                            : AppColors.neutral,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.showChevron) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.neutralLight,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
