import 'package:flutter_test/flutter_test.dart';
import 'package:pmes_mobile/core/models/dashboard_overview.dart';

void main() {
  test('assigned project parses details and its summary', () {
    final project = AssignedProject.fromJson({
      'id': 'project-1',
      'contract_ref': 'CTR-1',
      'title': 'Road rehabilitation',
      'section': null,
      'activity': 'Road works',
      'status': {'publication': 'Published', 'progress': 'In progress'},
      'milestone_completion': 0.5,
      'stats': {
        'approved_budget': 'MWK 1,000',
        'kpis_met': '2 of 4',
        'last_synced': '2026-11-05',
      },
      'location': {
        'latitude': '-15.4',
        'longitude': '28.2',
        'name': 'Lusaka',
        'accuracy': null,
      },
      'details': {
        'description': 'Improve access roads',
        'type': 'Infrastructure',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'duration': '12 months',
        'department': 'Transport',
        'project_category': 'Roads',
        'districts': 'Lusaka',
        'funders': 'Government',
        'budgets': 'MWK 1,000',
        'objectives': 'Improve road access',
        'staffing_requirements': '5',
        'employees': '4',
        'kpis': '4',
        'financial_transactions': '10',
        'documents': '3',
        'milestones': '2',
        'summary': {
          'total_budget': 'MWK 1,000',
          'total_expenses': 250,
          'budget_utilization_percentage': 25,
          'objectives_achievement_percentage': 50,
          'required_staff': 5,
          'employee_count': '4',
          'published_kpi_count': '4',
          'achieved_kpi_count': '2',
        },
      },
    });

    expect(project.details.description, 'Improve access roads');
    expect(project.details.startDate, '2026-01-01');
    expect(project.details.projectCategory, 'Roads');
    expect(project.details.staffingRequirements, '5');
    expect(project.details.financialTransactions, '10');
    expect(project.details.summary.totalBudget, 'MWK 1,000');
    expect(project.details.summary.totalExpenses, 250);
    expect(project.details.summary.budgetUtilizationPercentage, 25);
    expect(project.details.summary.objectivesAchievementPercentage, 50);
    expect(project.details.summary.requiredStaff, 5);
    expect(project.details.summary.achievedKpiCount, '2');
  });

  test('missing or null nested objects fall back to empty values', () {
    final project = AssignedProject.fromJson({
      'id': 1,
      'title': 'Bare project',
      'status': null,
      'stats': null,
      'location': null,
      'details': {'summary': null},
    });
    expect(project.id, '1');
    expect(project.details.description, '');
    expect(project.details.summary.totalExpenses, 0);
    expect(project.location.name, '');

    final noDetails = AssignedProject.fromJson({'id': 2});
    expect(noDetails.details.raw, isEmpty);

    final response = DashboardOverviewResponse.fromJson({
      'data': {
        'summary': null,
        'projects': [
          {'id': 3},
        ],
      },
    });
    expect(response.data.projects, hasLength(1));
  });
}
