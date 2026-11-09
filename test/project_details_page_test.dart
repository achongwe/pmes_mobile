import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pmes_mobile/core/models/dashboard_overview.dart';
import 'package:pmes_mobile/core/utils/detail_records.dart';
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
        'department': {'id': 6, 'name': 'Transport', 'code': 'TR'},
        'project_category': jsonEncode({'id': 2, 'name': 'Roads'}),
        'districts': 'Lusaka',
        'funders': 'Government',
        'budgets': 'MWK 1,000',
        'objectives': jsonEncode([
          {
            'id': 101,
            'project_id': 'project-1',
            'title': 'Improve road access',
            'status': 'Achieved',
          },
        ]),
        'staffing_requirements': [
          {'role': 'Site engineer', 'quantity': 2},
        ],
        'employees': [
          {'name': 'Jane Banda', 'role': 'Foreman'},
        ],
        'kpis': [
          {
            'name': 'Km paved',
            'project_id': 'project-1',
            'project_objective_id': 101,
            'status': 'Pending',
            'workflow_status': 'draft',
            'value': '5',
            'created_at': '2 hours ago',
            'updated_at': '1 hour ago',
          },
        ],
        'financial_transactions': jsonEncode([
          {
            'name': 'Cement purchase',
            'project_id': 'project-1',
            'user': 'John Banda',
            'user_id': 7,
            'amount': 1000000,
            'type': 'debit',
            'remark': 'First delivery',
            'created_at': '3 days ago',
            'updated_at': '2 days ago',
          },
          {
            'name': 'Grant',
            'project_id': 'project-1',
            'user': 'Jane Phiri',
            'user_id': 8,
            'amount': '2500000000000',
            'type': 'credit',
            'created_at': '1 day ago',
          },
        ]),
        'documents': [],
        'milestones': [
          {'title': 'Foundation', 'progress': 80, 'status': 'In progress'},
        ],
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

    expect(find.text('Project Details'), findsOneWidget);
    expect(find.text('Road rehabilitation'), findsOneWidget);
    expect(find.text('CONTRACT REF: CTR-1'), findsNothing);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Approved Budget'), findsOneWidget);
    expect(find.text('Achieved KPIs'), findsNothing);
    expect(find.text('Published KPIs'), findsNothing);
    expect(find.text('Milestone Completion'), findsNothing);
    expect(find.text('60%'), findsNothing);

    expect(groupThousands('MWK 1000'), 'MWK 1,000');
    expect(groupThousands('1234567.5'), '1,234,567.5');

    final scrollable = find.byType(Scrollable).first;
    Future<void> reveal(Finder finder) =>
        tester.scrollUntilVisible(finder, 300, scrollable: scrollable);

    await reveal(find.text('Objectives'));
    await reveal(find.text('Improve road access'));
    expect(find.text('Achieved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await reveal(find.text('Location & Timeline'));
    expect(find.text('Lusaka'), findsNWidgets(2));
    expect(find.text('1 January 2026'), findsOneWidget);
    expect(find.text('31 December 2026'), findsOneWidget);
    expect(find.text('Accuracy'), findsNothing);
    expect(find.text('Project ID'), findsNothing);

    await reveal(find.text('Site engineer'));
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('Jane Banda'), findsOneWidget);

    await reveal(find.text('Km paved'));
    expect(find.text('Improve road access'), findsWidgets);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);

    await reveal(find.text('Cement purchase'));
    expect(find.textContaining('John Banda'), findsNothing);
    expect(find.text('First delivery'), findsOneWidget);
    expect(find.text('MWK 1M'), findsOneWidget);
    expect(find.text('Debit'), findsOneWidget);
    expect(find.text('3 days ago'), findsNothing);
    expect(find.text('2 days ago'), findsNothing);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('MWK 2.5T'), findsOneWidget);

    await reveal(find.text('No documents uploaded.'));
  });
}
