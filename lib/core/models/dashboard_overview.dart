import '../utils/detail_records.dart';

/// Returns [value] as a map, or an empty map when it is null or not an object.
Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Response envelope for GET /dashboard/overview.
class DashboardOverviewResponse {
  final DashboardOverviewData data;
  final bool success;

  const DashboardOverviewResponse({required this.data, required this.success});

  factory DashboardOverviewResponse.fromJson(Map<String, dynamic> json) {
    return DashboardOverviewResponse(
      data: DashboardOverviewData.fromJson(_asMap(json['data'])),
      success: json['success'] as bool? ?? false,
    );
  }
}

class DashboardOverviewData {
  final DashboardSummary summary;
  final List<AssignedProject> projects;

  const DashboardOverviewData({required this.summary, required this.projects});

  factory DashboardOverviewData.fromJson(Map<String, dynamic> json) {
    return DashboardOverviewData(
      summary: DashboardSummary.fromJson(_asMap(json['summary'])),
      projects: (json['projects'] as List<dynamic>? ?? [])
          .map((e) => AssignedProject.fromJson(_asMap(e)))
          .toList(),
    );
  }
}

class DashboardSummary {
  final AssignedProjectsSummary assignedProjects;
  final FiscalAllocationSummary fiscalAllocation;
  final KpiOverviewSummary kpiOverview;

  const DashboardSummary({
    required this.assignedProjects,
    required this.fiscalAllocation,
    required this.kpiOverview,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      assignedProjects: AssignedProjectsSummary.fromJson(
        _asMap(json['assigned_projects']),
      ),
      fiscalAllocation: FiscalAllocationSummary.fromJson(
        _asMap(json['fiscal_allocation']),
      ),
      kpiOverview: KpiOverviewSummary.fromJson(
        _asMap(json['kpi_overview']),
      ),
    );
  }
}

class AssignedProjectsSummary {
  final String count;
  final String statusLabel;
  final String description;

  const AssignedProjectsSummary({
    required this.count,
    required this.statusLabel,
    required this.description,
  });

  factory AssignedProjectsSummary.fromJson(Map<String, dynamic> json) {
    return AssignedProjectsSummary(
      count: json['count']?.toString() ?? '0',
      statusLabel: json['status_label'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class FiscalAllocationSummary {
  final String formattedAmount;
  final String currency;
  final num? percentageChange;
  final String? fiscalYear;
  final String label;

  const FiscalAllocationSummary({
    required this.formattedAmount,
    required this.currency,
    required this.percentageChange,
    required this.fiscalYear,
    required this.label,
  });

  factory FiscalAllocationSummary.fromJson(Map<String, dynamic> json) {
    return FiscalAllocationSummary(
      formattedAmount: json['formatted_amount']?.toString() ?? '0',
      currency: json['currency'] as String? ?? '',
      percentageChange: json['percentage_change'] as num?,
      fiscalYear: json['fiscal_year'] as String?,
      label: json['label'] as String? ?? '',
    );
  }
}

class KpiOverviewSummary {
  final String verified;
  final String total;
  final num completionPercentage;
  final int nextReviewInDays;
  final String nextReviewLabel;

  const KpiOverviewSummary({
    required this.verified,
    required this.total,
    required this.completionPercentage,
    required this.nextReviewInDays,
    required this.nextReviewLabel,
  });

  factory KpiOverviewSummary.fromJson(Map<String, dynamic> json) {
    return KpiOverviewSummary(
      verified: json['verified']?.toString() ?? '0',
      total: json['total']?.toString() ?? '0',
      completionPercentage: json['completion_percentage'] as num? ?? 0,
      nextReviewInDays: json['next_review_in_days'] as int? ?? 0,
      nextReviewLabel: json['next_review_label'] as String? ?? '',
    );
  }
}

class AssignedProject {
  final String id;
  final String contractRef;
  final String title;
  final String? section;
  final String activity;
  final ProjectStatus status;
  final num milestoneCompletion;
  final ProjectStats stats;
  final ProjectLocation location;
  final ProjectDetails details;

  const AssignedProject({
    required this.id,
    required this.contractRef,
    required this.title,
    required this.section,
    required this.activity,
    required this.status,
    required this.milestoneCompletion,
    required this.stats,
    required this.location,
    required this.details,
  });

  factory AssignedProject.fromJson(Map<String, dynamic> json) {
    return AssignedProject(
      id: json['id']?.toString() ?? '',
      contractRef: json['contract_ref'] as String? ?? '',
      title: json['title'] as String? ?? '',
      section: json['section'] as String?,
      activity: json['activity'] as String? ?? '',
      status: ProjectStatus.fromJson(_asMap(json['status'])),
      milestoneCompletion: json['milestone_completion'] as num? ?? 0,
      stats: ProjectStats.fromJson(_asMap(json['stats'])),
      location: ProjectLocation.fromJson(_asMap(json['location'])),
      details: ProjectDetails.fromJson(_asMap(json['details'])),
    );
  }
}

class ProjectDetails {
  final String description;
  final String type;
  final String startDate;
  final String endDate;
  final String duration;
  final String department;
  final String projectCategory;
  final String districts;
  final String funders;
  final String budgets;
  final String objectives;
  final String staffingRequirements;
  final String employees;
  final String kpis;
  final String financialTransactions;
  final String documents;
  final String milestones;
  final ProjectDetailsSummary summary;

  /// Untouched `details` payload; nested fields may be JSON strings or lists.
  final Map<String, dynamic> raw;

  const ProjectDetails({
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.department,
    required this.projectCategory,
    required this.districts,
    required this.funders,
    required this.budgets,
    required this.objectives,
    required this.staffingRequirements,
    required this.employees,
    required this.kpis,
    required this.financialTransactions,
    required this.documents,
    required this.milestones,
    required this.summary,
    this.raw = const {},
  });

  factory ProjectDetails.fromJson(Map<String, dynamic> json) {
    return ProjectDetails(
      raw: json,
      description: json['description']?.toString() ?? '',
      type: displayText(json['type'], fallback: ''),
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      department: displayText(json['department'], fallback: ''),
      projectCategory: displayText(json['project_category'], fallback: ''),
      districts: displayText(json['districts'], fallback: ''),
      funders: displayText(json['funders'], fallback: ''),
      budgets: displayText(json['budgets'], fallback: ''),
      objectives: json['objectives']?.toString() ?? '',
      staffingRequirements: json['staffing_requirements']?.toString() ?? '',
      employees: json['employees']?.toString() ?? '',
      kpis: json['kpis']?.toString() ?? '',
      financialTransactions: json['financial_transactions']?.toString() ?? '',
      documents: json['documents']?.toString() ?? '',
      milestones: json['milestones']?.toString() ?? '',
      summary: ProjectDetailsSummary.fromJson(
        _asMap(json['summary']),
      ),
    );
  }
}

class ProjectDetailsSummary {
  final String totalBudget;
  final num totalExpenses;
  final num budgetUtilizationPercentage;
  final num objectivesAchievementPercentage;
  final num requiredStaff;
  final String employeeCount;
  final String publishedKpiCount;
  final String achievedKpiCount;

  const ProjectDetailsSummary({
    required this.totalBudget,
    required this.totalExpenses,
    required this.budgetUtilizationPercentage,
    required this.objectivesAchievementPercentage,
    required this.requiredStaff,
    required this.employeeCount,
    required this.publishedKpiCount,
    required this.achievedKpiCount,
  });

  factory ProjectDetailsSummary.fromJson(Map<String, dynamic> json) {
    return ProjectDetailsSummary(
      totalBudget: json['total_budget']?.toString() ?? '',
      totalExpenses: json['total_expenses'] as num? ?? 0,
      budgetUtilizationPercentage:
          json['budget_utilization_percentage'] as num? ?? 0,
      objectivesAchievementPercentage:
          json['objectives_achievement_percentage'] as num? ?? 0,
      requiredStaff: json['required_staff'] as num? ?? 0,
      employeeCount: json['employee_count']?.toString() ?? '',
      publishedKpiCount: json['published_kpi_count']?.toString() ?? '',
      achievedKpiCount: json['achieved_kpi_count']?.toString() ?? '',
    );
  }
}

class ProjectStatus {
  final String publication;
  final String progress;

  const ProjectStatus({required this.publication, required this.progress});

  factory ProjectStatus.fromJson(Map<String, dynamic> json) {
    return ProjectStatus(
      publication: json['publication'] as String? ?? '',
      progress: json['progress'] as String? ?? '',
    );
  }
}

class ProjectStats {
  final String approvedBudget;
  final String kpisMet;
  final String lastSynced;

  const ProjectStats({
    required this.approvedBudget,
    required this.kpisMet,
    required this.lastSynced,
  });

  factory ProjectStats.fromJson(Map<String, dynamic> json) {
    return ProjectStats(
      approvedBudget: json['approved_budget']?.toString() ?? '',
      kpisMet: json['kpis_met']?.toString() ?? '',
      lastSynced: json['last_synced']?.toString() ?? '',
    );
  }
}

class ProjectLocation {
  final String latitude;
  final String longitude;
  final String name;
  final num? accuracy;

  const ProjectLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.accuracy,
  });

  factory ProjectLocation.fromJson(Map<String, dynamic> json) {
    return ProjectLocation(
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      accuracy: json['accuracy'] as num?,
    );
  }
}
