import 'package:flutter/material.dart';

import '../../core/utils/detail_records.dart';

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ExtraFields extends StatelessWidget {
  const _ExtraFields(this.extras);

  final Map<String, String> extras;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final entry in extras.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

/// Shared card for one record; expands to show any leftover fields.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    this.leading,
    this.trailing,
    this.body,
  });

  final DetailRecord record;
  final Widget? leading;
  final Widget? trailing;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              if (record.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  record.subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (body != null) ...[const SizedBox(height: 8), body!],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: record.extras.isEmpty
          ? Padding(padding: const EdgeInsets.all(12), child: header)
          : Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: header,
                children: [_ExtraFields(record.extras)],
              ),
            ),
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({
    required this.value,
    required this.emptyMessage,
    required this.itemBuilder,
    this.maxHeight,
    this.recordBuilder,
  });

  final Object? value;
  final String emptyMessage;
  final Widget Function(BuildContext, DetailRecord) itemBuilder;
  final double? maxHeight;
  final DetailRecord Function(Object?)? recordBuilder;

  @override
  Widget build(BuildContext context) {
    final records = detailItems(value)
        .map((item) => recordBuilder?.call(item) ?? DetailRecord.from(item))
        .toList();
    if (records.isEmpty) return _EmptyNote(emptyMessage);

    final list = ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: maxHeight == null ? const NeverScrollableScrollPhysics() : null,
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => itemBuilder(context, records[index]),
    );
    if (maxHeight == null) return list;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: list,
    );
  }
}

Widget _statusIcon(BuildContext context, bool? done) {
  final colorScheme = Theme.of(context).colorScheme;
  return Icon(
    done == true ? Icons.check_circle : Icons.radio_button_unchecked,
    size: 22,
    color: done == true ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
  );
}

Widget? _statusBadge(BuildContext context, String? status, bool? done) {
  if (status == null) return null;
  final colorScheme = Theme.of(context).colorScheme;
  return _Badge(
    label: status,
    background: done == true
        ? colorScheme.tertiaryContainer
        : colorScheme.secondaryContainer,
    foreground: done == true
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSecondaryContainer,
  );
}

Widget? _workflowBadge(BuildContext context, String? workflowStatus) {
  if (workflowStatus == null) return null;
  final colorScheme = Theme.of(context).colorScheme;
  final published = workflowStatus == 'Published';
  return _Badge(
    label: workflowStatus,
    background: published
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest,
    foreground: published
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant,
  );
}

Widget? _kpiBadges(BuildContext context, DetailRecord record) {
  final workflow = _workflowBadge(context, record.workflowStatus);
  final status = _statusBadge(
    context,
    record.status ?? record.type,
    record.done,
  );
  if (workflow == null || status == null) return workflow ?? status;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [workflow, const SizedBox(height: 4), status],
  );
}

class FinancialTransactionsList extends StatelessWidget {
  const FinancialTransactionsList({
    required this.value,
    this.defaultCurrency = '',
    super.key,
  });

  final Object? value;
  final String defaultCurrency;

  static bool? _isCredit(String? type) {
    final lower = type?.toLowerCase() ?? '';
    if (lower.contains('credit') ||
        lower.contains('income') ||
        lower.contains('deposit')) {
      return true;
    }
    if (lower.contains('debit') ||
        lower.contains('expense') ||
        lower.contains('payment')) {
      return false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: 'No financial transactions recorded.',
      maxHeight: 360,
      recordBuilder: (item) => DetailRecord.from(
        item is Map ? (Map.of(item)..remove('user')) : item,
        includeWorkflowStatus: true,
        hiddenKeys: const {
          'project_id',
          'user_id',
          'date',
          'transaction_date',
          'created_at',
          'updated_at',
        },
      ),
      itemBuilder: (context, record) {
        final workflow = _workflowBadge(context, record.workflowStatus);
        final credit = _isCredit(record.type ?? record.status);
        final amountText = record.amount == null
            ? null
            : formatCompactAmount(record.amount!) ??
                  formatAmount(record.amount!) ??
                  record.amount!;
        final currency = record.currency ?? defaultCurrency;
        final label = record.type ?? record.status;
        final color = credit == null
            ? colorScheme.onSurface
            : credit
            ? colorScheme.tertiary
            : colorScheme.error;
        return _RecordCard(
          record: record,
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amountText != null)
                Text(
                  [currency, amountText].where((e) => e.isNotEmpty).join(' '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              if (label != null) ...[
                const SizedBox(height: 4),
                _Badge(
                  label: credit == null
                      ? label
                      : credit
                      ? 'Credit'
                      : 'Debit',
                  background: credit == null
                      ? colorScheme.secondaryContainer
                      : credit
                      ? colorScheme.tertiaryContainer
                      : colorScheme.errorContainer,
                  foreground: credit == null
                      ? colorScheme.onSecondaryContainer
                      : credit
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ],
              if (workflow != null) ...[const SizedBox(height: 4), workflow],
            ],
          ),
        );
      },
    );
  }
}

/// Objectives and KPIs: check-marked rows with a status badge.
class StatusChecklist extends StatelessWidget {
  const StatusChecklist({
    required this.value,
    required this.emptyMessage,
    this.showIcon = true,
    this.hiddenKeys = const {},
    super.key,
  });

  final Object? value;
  final String emptyMessage;
  final bool showIcon;
  final Set<String> hiddenKeys;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
      recordBuilder: (item) => DetailRecord.from(item, hiddenKeys: hiddenKeys),
      itemBuilder: (context, record) => _RecordCard(
        record: record,
        leading: showIcon ? _statusIcon(context, record.done) : null,
        trailing: _statusBadge(
          context,
          record.status ?? record.type,
          record.done,
        ),
        body: record.amount == null && record.percent == null
            ? null
            : Text(
                [
                  if (record.amount != null) record.amount!,
                  if (record.percent != null) '${record.percent!.round()}%',
                ].join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.secondary,
                ),
              ),
      ),
    );
  }
}

class KpiChecklist extends StatelessWidget {
  const KpiChecklist({
    required this.value,
    required this.objectives,
    this.emptyMessage = 'No KPIs recorded.',
    super.key,
  });

  final Object? value;
  final Object? objectives;
  final String emptyMessage;

  Map<String, String> _objectiveNamesById(Object? rawObjectives) {
    final names = <String, String>{};
    for (final item in detailItems(rawObjectives)) {
      if (item is! Map) continue;
      final id = item['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      final name = displayText(
        item['objective'] ?? item['name'] ?? item['title'],
        fallback: '',
      );
      if (name.trim().isNotEmpty) {
        names[id] = name;
      }
    }
    return names;
  }

  DetailRecord _buildKpiRecord(
    Object? item,
    Map<String, String> objectiveNamesById,
  ) {
    if (item is! Map) {
      return DetailRecord.from(
        item,
        hiddenKeys: const {
          'project_id',
          'project_objective_id',
          'objective_id',
        },
        includeWorkflowStatus: true,
      );
    }

    final map = Map<String, dynamic>.from(item);
    final objectiveId = map['project_objective_id'] ?? map['objective_id'];
    final existingObjective = map['project_objective'];
    if ((existingObjective == null ||
            existingObjective.toString().trim().isEmpty) &&
        objectiveId != null) {
      map['project_objective'] = objectiveNamesById[objectiveId.toString()];
    }

    return DetailRecord.from(
      map,
      hiddenKeys: const {'project_id', 'project_objective_id', 'objective_id'},
      includeWorkflowStatus: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final objectiveNamesById = _objectiveNamesById(objectives);
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
      recordBuilder: (item) => _buildKpiRecord(item, objectiveNamesById),
      itemBuilder: (context, record) => _RecordCard(
        record: record,
        trailing: _kpiBadges(context, record),
        body: record.amount == null && record.percent == null
            ? null
            : Text(
                [
                  if (record.amount != null) record.amount!,
                  if (record.percent != null) '${record.percent!.round()}%',
                ].join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.secondary,
                ),
              ),
      ),
    );
  }
}

/// Staffing requirement rows: the position name is the title and the
/// description sits beneath it. `project_id` and `updated_at` are not shown.
DetailRecord staffingRequirementRecord(Object? item) => DetailRecord.from(
  item,
  titleKeys: const [
    'position_name',
    'name',
    'full_name',
    'employee_name',
    'position',
    'role',
    'title',
  ],
  subtitleKeys: const ['description'],
  hiddenKeys: const {'project_id', 'updated_at'},
);

/// Staffing requirements and employees as compact person / role rows.
class StaffList extends StatelessWidget {
  const StaffList({
    required this.value,
    required this.emptyMessage,
    this.icon = Icons.person_outline,
    this.recordBuilder,
    super.key,
  });

  final Object? value;
  final String emptyMessage;
  final IconData icon;
  final DetailRecord Function(Object?)? recordBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
      recordBuilder: recordBuilder,
      itemBuilder: (context, record) => _RecordCard(
        record: record,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
        ),
        trailing: record.amount == null
            ? _statusBadge(context, record.status ?? record.type, record.done)
            : Text(
                '×${record.amount}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
      ),
    );
  }
}

/// Generic list for documents and any other structured `details` field.
class GenericRecordList extends StatelessWidget {
  const GenericRecordList({
    required this.value,
    required this.emptyMessage,
    super.key,
  });

  final Object? value;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
      itemBuilder: (context, record) => _RecordCard(
        record: record,
        trailing: _statusBadge(
          context,
          record.status ?? record.type,
          record.done,
        ),
      ),
    );
  }
}

/// Project documents returned by the API (media records).
class ProjectDocumentList extends StatelessWidget {
  const ProjectDocumentList({
    required this.value,
    required this.emptyMessage,
    super.key,
  });

  final Object? value;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final documents = detailItems(value).whereType<Map>().toList();
    if (documents.isEmpty) return _EmptyNote(emptyMessage);

    return Column(
      children: [
        for (var i = 0; i < documents.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildCard(context, colorScheme, documents[i]),
        ],
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme colorScheme,
    Map document,
  ) {
    final name = _text(document['name']) ?? _text(document['file_name']);
    final fileName = _text(document['file_name']);
    final description = _text(document['description']);
    final mediaType = _text(document['media_type']);
    final size = _formatFileSize(document['size']);
    final details = [
      ?mediaType,
      if (fileName != null && fileName != name) fileName,
      ?size,
    ].join(' • ');
    final workflowStatus = DetailRecord.from(
      document,
      includeWorkflowStatus: true,
    ).workflowStatus;

    return _RecordCard(
      record: DetailRecord(title: name ?? '—', subtitle: description),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(
          Icons.description_outlined,
          size: 18,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      trailing: _workflowBadge(context, workflowStatus),
      body: details.isEmpty
          ? null
          : Text(
              details,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }

  static String? _text(Object? value) {
    if (value == null || value is Map || value is List) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _formatFileSize(Object? value) {
    final bytes = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (bytes == null) return null;
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
    return '${bytes.toInt()} B';
  }
}
