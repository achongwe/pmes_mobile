import 'package:flutter/material.dart';

import '../core/models/dashboard_overview.dart';

class ProjectDetailsPage extends StatelessWidget {
  const ProjectDetailsPage({required this.project, super.key});

  final AssignedProject project;

  String _value(String value) {
    final plainText = value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return plainText.isEmpty ? '—' : plainText;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = project.details;
    final summary = details.summary;
    final location = project.location;

    return Scaffold(
      appBar: AppBar(title: const Text('Project details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Project ID: ${_value(project.id)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Project code: ${_value(project.contractRef)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (project.section?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    _LabeledValue(
                      label: 'Section',
                      value: _value(project.section!),
                    ),
                  ],
                  if (project.activity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _LabeledValue(
                      label: 'Activity',
                      value: _value(project.activity),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: 'Publication: ${_value(project.status.publication)}',
                      ),
                      _StatusChip(
                        label: 'Progress: ${_value(project.status.progress)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.donut_large,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Milestone completion',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${project.milestoneCompletion}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (project.milestoneCompletion / 100)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
          ),
          _DetailsSection(
            title: 'Project information',
            children: [
              _LabeledValue(
                label: 'Description',
                value: _value(details.description),
              ),
              _LabeledValue(label: 'Type', value: _value(details.type)),
              _LabeledValue(
                label: 'Start date',
                value: _value(details.startDate),
              ),
              _LabeledValue(label: 'End date', value: _value(details.endDate)),
              _LabeledValue(label: 'Duration', value: _value(details.duration)),
              _LabeledValue(
                label: 'Department',
                value: _value(details.department),
              ),
              _LabeledValue(
                label: 'Project category',
                value: _value(details.projectCategory),
              ),
              _LabeledValue(
                label: 'Districts',
                value: _value(details.districts),
              ),
              _LabeledValue(label: 'Funders', value: _value(details.funders)),
              _LabeledValue(label: 'Budgets', value: _value(details.budgets)),
              _LabeledValue(
                label: 'Objectives',
                value: _value(details.objectives),
              ),
              _LabeledValue(
                label: 'Staffing requirements',
                value: _value(details.staffingRequirements),
              ),
              _LabeledValue(
                label: 'Employees',
                value: _value(details.employees),
              ),
              _LabeledValue(label: 'KPIs', value: _value(details.kpis)),
              _LabeledValue(
                label: 'Financial transactions',
                value: _value(details.financialTransactions),
              ),
              _LabeledValue(label: 'Documents', value: _value(details.documents)),
              _LabeledValue(
                label: 'Milestones',
                value: _value(details.milestones),
              ),
            ],
          ),
          _DetailsSection(
            title: 'Project statistics',
            children: [
              _LabeledValue(
                label: 'Approved budget',
                value: _value(project.stats.approvedBudget),
              ),
              _LabeledValue(
                label: 'KPIs met',
                value: _value(project.stats.kpisMet),
              ),
              _LabeledValue(
                label: 'Last synced',
                value: _value(project.stats.lastSynced),
              ),
              _LabeledValue(
                label: 'Total budget',
                value: _value(summary.totalBudget),
              ),
              _LabeledValue(
                label: 'Total expenses',
                value: summary.totalExpenses.toString(),
              ),
              _LabeledValue(
                label: 'Budget utilization',
                value: '${summary.budgetUtilizationPercentage}%',
              ),
              _LabeledValue(
                label: 'Objectives achieved',
                value: '${summary.objectivesAchievementPercentage}%',
              ),
              _LabeledValue(
                label: 'Required staff',
                value: summary.requiredStaff.toString(),
              ),
              _LabeledValue(
                label: 'Employee count',
                value: _value(summary.employeeCount),
              ),
              _LabeledValue(
                label: 'Published KPI count',
                value: _value(summary.publishedKpiCount),
              ),
              _LabeledValue(
                label: 'Achieved KPI count',
                value: _value(summary.achievedKpiCount),
              ),
            ],
          ),
          _DetailsSection(
            title: 'Location',
            children: [
              _LabeledValue(label: 'Name', value: _value(location.name)),
              _LabeledValue(
                label: 'Latitude',
                value: _value(location.latitude),
              ),
              _LabeledValue(
                label: 'Longitude',
                value: _value(location.longitude),
              ),
              _LabeledValue(
                label: 'Accuracy',
                value: location.accuracy == null
                    ? '—'
                    : '${location.accuracy} m',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
