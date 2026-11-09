/// A KPI that already exists on a project (from the project's `kpis` list).
class ProjectKpi {
  const ProjectKpi({
    required this.id,
    required this.name,
    required this.baselineValue,
    required this.targetValue,
    required this.aggregationMethod,
    required this.reportingPeriod,
    required this.description,
    this.objectiveId,
    this.achievedValue,
    this.status,
  });

  final String id;
  final String name;
  final String? objectiveId;
  final String baselineValue;
  final String targetValue;
  final String? achievedValue;
  final String aggregationMethod;
  final String reportingPeriod;
  final String description;
  final String? status;

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// Returns null when the map has no usable KPI id.
  static ProjectKpi? tryParse(Map<dynamic, dynamic> map) {
    final id = _text(map['id'] ?? map['kpi_id']);
    if (id == null) return null;
    return ProjectKpi(
      id: id,
      name: _text(map['name']) ?? 'KPI $id',
      objectiveId: _text(map['project_objective_id'] ?? map['objective_id']),
      baselineValue: _text(map['baseline_value']) ?? '0',
      targetValue: _text(map['target_value']) ?? '0',
      achievedValue: _text(map['achieved_value']),
      aggregationMethod: _text(map['aggregation_method']) ?? '',
      reportingPeriod: _text(map['reporting_period']) ?? '',
      description: _text(map['description']) ?? '',
      status: _text(map['status']),
    );
  }

  ProjectKpi copyWith({
    String? name,
    String? objectiveId,
    bool clearObjective = false,
    String? baselineValue,
    String? targetValue,
    String? aggregationMethod,
    String? reportingPeriod,
    String? description,
  }) {
    return ProjectKpi(
      id: id,
      name: name ?? this.name,
      objectiveId: clearObjective ? null : (objectiveId ?? this.objectiveId),
      baselineValue: baselineValue ?? this.baselineValue,
      targetValue: targetValue ?? this.targetValue,
      achievedValue: achievedValue,
      aggregationMethod: aggregationMethod ?? this.aggregationMethod,
      reportingPeriod: reportingPeriod ?? this.reportingPeriod,
      description: description ?? this.description,
      status: status,
    );
  }
}
