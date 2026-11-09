import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/models/project_kpi.dart';
import 'create_kpi_screen.dart';

class UpdateKpiArgs {
  const UpdateKpiArgs({
    required this.projectId,
    required this.projectTitle,
    required this.objectives,
    required this.kpis,
  });

  final String projectId;
  final String projectTitle;
  final List<ObjectiveOption> objectives;
  final List<ProjectKpi> kpis;
}

/// Lists every KPI of a project; "Add record" opens the KPI form, which
/// sends a PUT to update that KPI.
class UpdateKpiScreen extends StatefulWidget {
  const UpdateKpiScreen({required this.args, super.key});

  final UpdateKpiArgs args;

  @override
  State<UpdateKpiScreen> createState() => _UpdateKpiScreenState();
}

class _UpdateKpiScreenState extends State<UpdateKpiScreen> {
  late List<ProjectKpi> _kpis = List.of(widget.args.kpis);
  bool _changed = false;

  Future<void> _addRecord(ProjectKpi kpi) async {
    final updated = await context.pushNamed<ProjectKpi>(
      'project-edit-kpi',
      extra: CreateKpiArgs(
        projectId: widget.args.projectId,
        projectTitle: widget.args.projectTitle,
        objectives: widget.args.objectives,
        kpi: kpi,
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _changed = true;
      _kpis = [
        for (final item in _kpis) item.id == updated.id ? updated : item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Update KPI')),
        body: SafeArea(
          child: _kpis.isEmpty
              ? const Center(child: Text('No KPIs recorded for this project.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _kpis.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        widget.args.projectTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    final kpi = _kpis[index - 1];
                    return _KpiCard(
                      kpi: kpi,
                      onAddRecord: () => _addRecord(kpi),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, required this.onAddRecord});

  final ProjectKpi kpi;
  final VoidCallback onAddRecord;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = [
      'Baseline ${kpi.baselineValue}',
      'Target ${kpi.targetValue}',
      if (kpi.achievedValue != null) 'Achieved ${kpi.achievedValue}',
      if (kpi.status != null) kpi.status!,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onAddRecord,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add record'),
            ),
          ),
        ],
      ),
    );
  }
}
