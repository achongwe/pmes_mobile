import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pmes_mobile/core/models/dashboard_overview.dart';
import 'package:pmes_mobile/pages/project_details_page.dart';

void main() {
  testWidgets('shows project details and summary returned by the API', (
    tester,
  ) async {
    final project = AssignedProject.fromJson({
      'id': 'project-1',
      'contract_ref': 'CTR-1',
      'title': 'Road rehabilitation',
      'section': 'Infrastructure',
      'activity': 'Road works',
      'status': {'publication': 'Published', 'progress': 'In progress'},
      'milestone_completion': 60,
      'stats': {
        'approved_budget': 'MWK 1,000',
        'kpis_met': '2 of 4',
        'last_synced': '2026-11-05',
      },
      'location': {
        'latitude': '-15.4',
        'longitude': '28.2',
        'name': 'Lusaka',
        'accuracy': 5,
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

    await tester.pumpWidget(
      MaterialApp(home: ProjectDetailsPage(project: project)),
    );

    expect(find.text('Road rehabilitation'), findsOneWidget);
    expect(find.text('Project ID: project-1'), findsOneWidget);
    expect(find.text('Project information'), findsOneWidget);
    expect(find.text('Improve access roads'), findsOneWidget);
    expect(find.text('Financial transactions'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Project statistics'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Project statistics'), findsOneWidget);
    expect(find.text('Budget utilization'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Location'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Lusaka'), findsOneWidget);
  });
}
