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
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
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
  });

  final Object? value;
  final String emptyMessage;
  final Widget Function(BuildContext, DetailRecord) itemBuilder;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final records = detailItems(value).map(DetailRecord.from).toList();
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
      itemBuilder: (context, record) {
        final credit = _isCredit(record.type ?? record.status);
        final amountText = record.amount == null
            ? null
            : formatAmount(record.amount!) ?? record.amount!;
        final currency = record.currency ?? defaultCurrency;
        final label = record.type ?? record.status;
        final color = credit == null
            ? colorScheme.onSurface
            : credit
            ? colorScheme.tertiary
            : colorScheme.error;
        return _RecordCard(
          record: record,
          body: record.date == null
              ? null
              : Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.date!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
    super.key,
  });

  final Object? value;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
      itemBuilder: (context, record) => _RecordCard(
        record: record,
        leading: _statusIcon(context, record.done),
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

class MilestonesList extends StatelessWidget {
  const MilestonesList({required this.value, super.key});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: 'No milestones recorded.',
      itemBuilder: (context, record) {
        final percent = record.percent;
        return _RecordCard(
          record: record,
          leading: _statusIcon(
            context,
            record.done ?? (percent == null ? null : percent >= 100),
          ),
          trailing: _statusBadge(context, record.status, record.done),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (percent != null)
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (percent / 100).clamp(0.0, 1.0).toDouble(),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percent.round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (record.date != null)
                Padding(
                  padding: EdgeInsets.only(top: percent == null ? 0 : 6),
                  child: Text(
                    'Due ${record.date}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Staffing requirements and employees as compact person / role rows.
class StaffList extends StatelessWidget {
  const StaffList({
    required this.value,
    required this.emptyMessage,
    this.icon = Icons.person_outline,
    super.key,
  });

  final Object? value;
  final String emptyMessage;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _RecordList(
      value: value,
      emptyMessage: emptyMessage,
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
