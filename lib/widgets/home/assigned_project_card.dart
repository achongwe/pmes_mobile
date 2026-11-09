import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/dashboard_overview.dart';
import '../../core/models/evidence_item.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/session_provider.dart';
import '../../core/utils/detail_records.dart';
import '../../pages/create_kpi_screen.dart';
import '../../pages/project_gps_update_page.dart';
import '../../pages/record_financial_transaction_screen.dart';
import 'project_map_banner.dart';

enum _ProgressAction {
  updateKpiStatus,
  updateBudgetStatus,
  uploadProgressEvidence,
}

enum _EvidenceSource { photo, video, document }

const _documentExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
];
const _maxVideoDuration = Duration(minutes: 1);

class AssignedProjectCard extends StatefulWidget {
  const AssignedProjectCard({
    required this.project,
    this.onDataChanged,
    super.key,
  });

  final AssignedProject project;
  final Future<void> Function()? onDataChanged;

  @override
  State<AssignedProjectCard> createState() => _AssignedProjectCardState();
}

class _AssignedProjectCardState extends State<AssignedProjectCard> {
  final ImagePicker _imagePicker = ImagePicker();
  static const DashboardService _dashboardService = DashboardService();
  EvidenceItem? _pendingEvidence;
  bool _isUploadingEvidence = false;

  static String? _textValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String? _firstTextValue(
    Map<dynamic, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final text = _textValue(source[key]);
      if (text != null) return text;
    }
    return null;
  }

  List<ObjectiveOption> _objectiveOptions() {
    final options = <ObjectiveOption>[];
    final seenIds = <String>{};
    final objectiveItems = detailItems(
      widget.project.details.raw['objectives'],
    );

    for (final item in objectiveItems) {
      if (item is! Map) continue;
      final id = _firstTextValue(item, const ['id', 'objective_id', 'uuid']);
      if (id == null || !seenIds.add(id)) continue;
      final label =
          _firstTextValue(item, const ['name', 'title', 'objective']) ??
          displayText(item, fallback: id);
      options.add(ObjectiveOption(id: id, label: label));
    }

    return options;
  }

  static String _stripHtml(String value, {int maxLength = 220}) {
    final plainText = value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (plainText.length <= maxLength) return plainText;
    return '${plainText.substring(0, maxLength).trim()}…';
  }

  Future<_ProgressAction?> _showLogProgressOptionsSheet() {
    return showModalBottomSheet<_ProgressAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.rule_folder_outlined),
              title: const Text('Update KPI Status'),
              subtitle: const Text('Record KPI progress and adjustments'),
              onTap: () =>
                  Navigator.pop(context, _ProgressAction.updateKpiStatus),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Update Budget Status'),
              subtitle: const Text('Record budget usage and changes'),
              onTap: () =>
                  Navigator.pop(context, _ProgressAction.updateBudgetStatus),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Upload Progress Evidence'),
              subtitle: const Text(
                'Take a picture, record a video, or upload a document',
              ),
              onTap: () => Navigator.pop(
                context,
                _ProgressAction.uploadProgressEvidence,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onLogProgressPressed() async {
    final action = await _showLogProgressOptionsSheet();
    if (!mounted || action == null) return;

    switch (action) {
      case _ProgressAction.updateKpiStatus:
        final created = await context.pushNamed<bool>(
          'project-create-kpi',
          extra: CreateKpiArgs(
            projectId: widget.project.id,
            projectTitle: widget.project.title,
            objectives: _objectiveOptions(),
          ),
        );
        if (created == true) await widget.onDataChanged?.call();
        break;
      case _ProgressAction.updateBudgetStatus:
        final recorded = await context.pushNamed<bool>(
          'project-record-expenditure',
          extra: RecordFinancialTransactionArgs(
            projectId: widget.project.id,
            projectTitle: widget.project.title,
            objectives: _objectiveOptions(),
          ),
        );
        if (recorded == true) await widget.onDataChanged?.call();
        break;
      case _ProgressAction.uploadProgressEvidence:
        await _selectProgressEvidence();
        break;
    }
  }

  Future<void> _selectProgressEvidence() async {
    final source = await showModalBottomSheet<_EvidenceSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a picture'),
              onTap: () => Navigator.pop(context, _EvidenceSource.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record a video'),
              subtitle: const Text('Up to 1 minute'),
              onTap: () => Navigator.pop(context, _EvidenceSource.video),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Upload a document'),
              subtitle: const Text('PDF, Word, Excel, PowerPoint or text'),
              onTap: () => Navigator.pop(context, _EvidenceSource.document),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final EvidenceType type;
      final XFile? file;
      switch (source) {
        case _EvidenceSource.photo:
          type = EvidenceType.photo;
          file = await _imagePicker.pickImage(source: ImageSource.camera);
        case _EvidenceSource.video:
          type = EvidenceType.video;
          file = await _imagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration: _maxVideoDuration,
          );
        case _EvidenceSource.document:
          type = EvidenceType.document;
          final result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: _documentExtensions,
          );
          final path = result?.path;
          if (result != null && path == null) {
            _showMessage('Unable to access the selected file.');
            return;
          }
          file = path == null ? null : XFile(path);
      }
      if (!mounted || file == null) return;

      final sizeBytes = await file.length();
      if (!mounted) return;
      setState(() {
        _pendingEvidence = EvidenceItem(
          file: file!,
          type: type,
          sizeBytes: sizeBytes,
        );
      });
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(error.message ?? 'Unable to open the selected source.');
      }
    }
  }

  Future<void> _uploadProgressEvidence() async {
    final evidence = _pendingEvidence;
    if (evidence == null || _isUploadingEvidence) return;

    final token = context.read<SessionProvider>().token;
    if (token == null) {
      _showMessage('You are not signed in. Please log in again.');
      return;
    }

    final project = widget.project;
    setState(() => _isUploadingEvidence = true);

    try {
      await _dashboardService.uploadProjectDocument(
        token: token,
        projectId: project.id,
        file: evidence.file,
        name: _truncate('Progress ${evidence.label}: ${project.title}', 255),
        description: _truncate(
          'Progress ${evidence.label} for ${project.title}',
          500,
        ),
      );
      if (!mounted) return;
      setState(() => _pendingEvidence = null);
      _showMessage('Progress ${evidence.label} uploaded.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isUploadingEvidence = false);
    }
  }

  static String _truncate(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);

  Widget _buildEvidencePreview(EvidenceItem evidence) {
    final colorScheme = Theme.of(context).colorScheme;
    const tileSize = 76.0;

    final Widget tile;
    switch (evidence.type) {
      case EvidenceType.photo:
        tile = Image.file(
          File(evidence.file.path),
          width: tileSize,
          height: tileSize,
          fit: BoxFit.cover,
        );
      case EvidenceType.video:
        tile = Container(
          width: tileSize,
          height: tileSize,
          color: Colors.black87,
          child: const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 36,
          ),
        );
      case EvidenceType.document:
        tile = Container(
          width: tileSize,
          height: tileSize,
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            evidence.isPdf
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 36,
          ),
        );
    }

    return Row(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: tile),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                evidence.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${evidence.label[0].toUpperCase()}${evidence.label.substring(1)}'
                ' • ${evidence.formattedSize}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove ${evidence.label}',
          onPressed: _isUploadingEvidence
              ? null
              : () => setState(() => _pendingEvidence = null),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final project = widget.project;
    final section = project.section != null && project.section!.isNotEmpty
        ? _stripHtml(project.section!)
        : null;
    final activity = project.activity.isNotEmpty
        ? _stripHtml(project.activity)
        : null;
    final subtitle = [
      if (section != null && section.isNotEmpty) section,
      if (activity != null && activity.isNotEmpty) activity,
    ].join(' • ');
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.pushNamed('project-details', extra: project),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'PROJECT CODE: ${project.contractRef}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusTag(
                        label: project.status.publication,
                        color: colorScheme.secondaryContainer,
                        textColor: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      _StatusTag(
                        label: project.status.progress,
                        color: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  height: 1.25,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSmallSpecCard(
                      icon: Icons.payments_outlined,
                      title: project.stats.approvedBudget,
                      subtitle: 'Approved',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallSpecCard(
                      icon: Icons.verified_outlined,
                      title: project.stats.kpisMet,
                      subtitle: 'KPIs Met',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallSpecCard(
                      icon: Icons.access_time_rounded,
                      title: project.stats.lastSynced,
                      subtitle: 'Last Synced',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProjectMapBanner(location: project.location),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.pushNamed(
                          'project-gps-update',
                          extra: ProjectGpsUpdateArgs(
                            projectId: project.id,
                            projectTitle: project.title,
                            location: project.location,
                          ),
                        );
                      },
                      icon: const Icon(Icons.near_me_outlined, size: 16),
                      label: const Text(
                        'Update GPS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: _buttonStyle(
                        colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingEvidence
                          ? null
                          : _onLogProgressPressed,
                      icon: const Icon(Icons.edit_note_outlined, size: 16),
                      label: const Text(
                        'Log Progress',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: _buttonStyle(
                        colorScheme.secondary,
                        foregroundColor: colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_pendingEvidence case final evidence?) ...[
                const SizedBox(height: 12),
                _buildEvidencePreview(evidence),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingEvidence
                        ? null
                        : _uploadProgressEvidence,
                    icon: _isUploadingEvidence
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(
                      _isUploadingEvidence
                          ? 'Uploading ${evidence.label}…'
                          : 'Upload ${evidence.label}',
                    ),
                    style: _buttonStyle(
                      colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallSpecCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colorScheme.secondary),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle(
    Color backgroundColor, {
    required Color foregroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
