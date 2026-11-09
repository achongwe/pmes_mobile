import 'dart:io';

import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../core/services/api_exception.dart';
import '../core/services/user_profile_service.dart';
import '../core/theme/app_colors.dart';

class BasicInformationPage extends StatefulWidget {
  const BasicInformationPage({
    required this.userName,
    required this.userEmail,
    this.profilePhotoPath,
    this.onProfileUpdated,
    this.token,
    this.profileService = const UserProfileService(),
    this.organization,
    this.department,
    super.key,
  });

  final String? userName;
  final String? userEmail;
  final String? profilePhotoPath;
  final Future<void> Function(ProfileUser)? onProfileUpdated;
  final String? token;
  final UserProfileService profileService;
  final String? organization;
  final String? department;

  @override
  State<BasicInformationPage> createState() => _BasicInformationPageState();
}

class _BasicInformationPageState extends State<BasicInformationPage> {
  late _BasicInformationData _details;
  bool _isSaving = false;

  String get _email => _details.email.trim().isNotEmpty
      ? _details.email.trim()
      : widget.userEmail?.trim().isNotEmpty == true
      ? widget.userEmail!.trim()
      : 'Email unavailable';

  String get _name {
    final name = _details.name.trim();
    return name.isNotEmpty ? name : 'Name unavailable';
  }

  @override
  void initState() {
    super.initState();
    _details = _BasicInformationData(
      name: widget.userName?.trim() ?? '',
      email: widget.userEmail?.trim() ?? '',
    );
  }

  Future<void> _editDetails() async {
    final updated = await showModalBottomSheet<_BasicInformationData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditBasicInformationSheet(initial: _details),
    );
    if (updated == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final token = widget.token;
      if (token == null || token.isEmpty) {
        _showMessage('Your session has expired. Please sign in again.');
        return;
      }
      final nameParts = updated.name.trim().split(RegExp(r'\s+'));
      if (nameParts.length < 2) {
        _showMessage('Enter your first and last name.');
        return;
      }
      final firstName = nameParts.first;
      final lastName = nameParts.skip(1).join(' ');
      final email = updated.email.trim();

      final response = await widget.profileService.updateProfile(
        token: token,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      final savedName = response.user.displayName ?? updated.name;
      final savedEmail = response.user.email ?? email;
      final savedDetails = _BasicInformationData(
        name: savedName,
        email: savedEmail,
      );
      if (mounted) setState(() => _details = savedDetails);
      await widget.onProfileUpdated?.call(response.user);
      if (mounted) _showMessage('Your profile has been updated.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception {
      if (mounted) {
        _showMessage(
          'Profile updated, but the local session could not refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.card,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back to Profile',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 4,
        title: const Text('Basic Information'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                children: [
                  const SizedBox(height: 20),
                  _ProfileSummaryCard(
                    name: _name,
                    email: _email,
                    organization: _value(widget.organization ?? ''),
                    department: _value(widget.department ?? ''),
                    photoPath: widget.profilePhotoPath,
                    isSaving: _isSaving,
                    onEdit: _isSaving ? null : _editDetails,
                  ),
                  const SizedBox(height: 16),
                  _InformationCard(
                    title: 'PERSONAL DETAILS',
                    rows: [
                      _InformationRowData(
                        Icons.person_outline_rounded,
                        'Full Name',
                        _name,
                      ),
                      _InformationRowData(
                        Icons.mail_outline_rounded,
                        'Email Address',
                        _email,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _value(String value) => value.trim().isEmpty ? 'Not provided' : value;
}

class _BasicInformationData {
  const _BasicInformationData({this.name = '', this.email = ''});

  final String name;
  final String email;
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.name,
    required this.email,
    required this.organization,
    required this.department,
    required this.photoPath,
    required this.isSaving,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String organization;
  final String department;
  final String? photoPath;
  final bool isSaving;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: photoPath == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 38,
                      color: AppColors.secondary,
                    )
                  : Image.file(
                      File(photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person_rounded,
                        size: 38,
                        color: AppColors.secondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PMES Account',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Department: $organization',
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(isSaving ? 'Saving' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _InformationRowData {
  const _InformationRowData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.rows});

  final String title;
  final List<_InformationRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.neutral,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            _InformationRow(data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                indent: 42,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.data});

  final _InformationRowData data;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Icon(data.icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.58),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _EditBasicInformationSheet extends StatefulWidget {
  const _EditBasicInformationSheet({required this.initial});

  final _BasicInformationData initial;

  @override
  State<_EditBasicInformationSheet> createState() =>
      _EditBasicInformationSheetState();
}

class _EditBasicInformationSheetState
    extends State<_EditBasicInformationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial.name);
  late final _emailController = TextEditingController(
    text: widget.initial.email,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _BasicInformationData(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.secondary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit personal details',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Full name',
                        Icons.person_outline_rounded,
                      ),
                      maxLength: 511,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        final parts = name.split(RegExp(r'\s+'));
                        if (name.isEmpty || parts.length < 2) {
                          return 'Enter your first and last name.';
                        }
                        if (parts.first.length > 255 ||
                            parts.skip(1).join(' ').length > 255) {
                          return 'First and last names must be 255 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        'Email address',
                        Icons.mail_outline_rounded,
                      ),
                      maxLength: 255,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email address.';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
