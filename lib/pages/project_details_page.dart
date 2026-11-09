import 'package:flutter/material.dart';

import '../core/models/dashboard_overview.dart';
import '../core/utils/detail_records.dart';
import '../widgets/project/project_detail_lists.dart';

class ProjectDetailsPage extends StatelessWidget {
  const ProjectDetailsPage({
    required this.project,
    this.currency = 'MWK',
    super.key,
  });

  final AssignedProject project;

  /// Used when a transaction doesn't carry its own currency.
  final String currency;

  static String _text(String? value) {
    final plain = (value ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return plain.isEmpty ? '—' : plain;
  }

  static String _percent(num value) => '${value.round()}%';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = project.details;
    final raw = details.raw;
    final summary = details.summary;
    final location = project.location;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.contractRef.trim().isNotEmpty)
              Text(
                project.contractRef.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            Text(
              'Project Details',
              style: TextStyle(
                fontWeight: project.contractRef.trim().isEmpty
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: project.contractRef.trim().isEmpty ? null : 13,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            title: _text(project.title),
            publication: _text(project.status.publication),
            progress: _text(project.status.progress),
            department: displayText(
              raw['department'],
              fallback: 'No department',
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.payments_outlined,
                    label: 'Approved Budget',
                    value: _text(project.stats.approvedBudget),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.verified_outlined,
                    label: 'KPIs Met',
                    value: _text(project.stats.kpisMet),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Overview',
            icon: Icons.description_outlined,
            children: [
              _InfoRow(
                label: 'Description',
                value: displayText(raw['description']),
              ),
              _InfoRow(label: 'Type', value: displayText(raw['type'])),
              _InfoRow(
                label: 'Category',
                value: displayText(raw['project_category']),
              ),
              _InfoRow(label: 'Funders', value: displayText(raw['funders'])),
              _InfoRow(
                label: 'Objectives achieved',
                value: _percent(summary.objectivesAchievementPercentage),
              ),
              const _SubHeading('Objectives'),
              StatusChecklist(
                value: raw['objectives'],
                emptyMessage: 'No objectives recorded.',
                showIcon: false,
                hiddenKeys: const {'project_id'},
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Location & Timeline',
            icon: Icons.place_outlined,
            children: [
              _InfoRow(label: 'Location', value: _text(location.name)),
              _InfoRow(
                label: 'Districts',
                value: displayText(raw['districts']),
              ),
              _InfoRow(label: 'Latitude', value: _text(location.latitude)),
              _InfoRow(label: 'Longitude', value: _text(location.longitude)),
              _InfoRow(
                label: 'Start date',
                value: formatLongDate(displayText(raw['start_date'])),
              ),
              _InfoRow(
                label: 'End date',
                value: formatLongDate(displayText(raw['end_date'])),
              ),
              _InfoRow(label: 'Duration', value: displayText(raw['duration'])),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Resources & Staffing',
            icon: Icons.groups_outlined,
            children: [
              _InfoRow(
                label: 'Required staff',
                value: summary.requiredStaff.toString(),
              ),
              _InfoRow(
                label: 'Employee count',
                value: _text(summary.employeeCount),
              ),
              _InfoRow(label: 'Budgets', value: displayText(raw['budgets'])),
              _InfoRow(
                label: 'Total budget',
                value: groupThousands(_text(summary.totalBudget)),
              ),
              _InfoRow(
                label: 'Total expenses',
                value: groupThousands(summary.totalExpenses.toString()),
              ),
              _InfoRow(
                label: 'Budget utilization',
                value: _percent(summary.budgetUtilizationPercentage),
              ),
              const _SubHeading('Staffing requirements'),
              StaffList(
                value: raw['staffing_requirements'],
                emptyMessage: 'No staffing requirements recorded.',
                icon: Icons.badge_outlined,
                recordBuilder: staffingRequirementRecord,
              ),
              const _SubHeading('Employees'),
              StaffList(
                value: raw['employees'],
                emptyMessage: 'No employees assigned.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'KPIs',
            icon: Icons.verified_outlined,
            children: [
              KpiChecklist(value: raw['kpis'], objectives: raw['objectives']),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Financial Transactions',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              FinancialTransactionsList(
                value: raw['financial_transactions'],
                defaultCurrency: currency,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Documents',
            icon: Icons.folder_open_outlined,
            children: [
              ProjectDocumentList(
                value: raw['documents'],
                emptyMessage: 'No documents uploaded.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.publication,
    required this.progress,
    required this.department,
  });

  final String title;
  final String publication;
  final String progress;
  final String department;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onPrimary = colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.bold,
              color: onPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroTag(
                label: publication,
                background: colorScheme.secondaryContainer,
                foreground: colorScheme.onSecondaryContainer,
              ),
              _HeroTag(
                label: progress,
                background: onPrimary.withValues(alpha: 0.16),
                foreground: onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.apartment_outlined,
                size: 16,
                color: onPrimary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  department,
                  style: TextStyle(
                    fontSize: 13,
                    color: onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
