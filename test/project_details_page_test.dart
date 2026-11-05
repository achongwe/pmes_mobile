import 'dart:convert';

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
        'department': {'id': 6, 'name': 'Transport', 'code': 'TR'},
        'project_category': jsonEncode({'id': 2, 'name': 'Roads'}),
        'districts': 'Lusaka',
        'funders': 'Government',
        'budgets': 'MWK 1,000',
        'objectives': jsonEncode([
          {'title': 'Improve road access', 'status': 'Achieved'},
        ]),
        'staffing_requirements': [
          {'role': 'Site engineer', 'quantity': 2},
        ],
        'employees': [
          {'name': 'Jane Banda', 'role': 'Foreman'},
        ],
        'kpis': [
          {'name': 'Km paved', 'status': 'Pending', 'value': '5'},
        ],
        'financial_transactions': jsonEncode([
          {
            'name': 'Cement purchase',
            'amount': 1500,
            'type': 'debit',
            'remark': 'First delivery',
            'date': '2026-03-01',
          },
          {'name': 'Grant', 'amount': '2500', 'type': 'credit'},
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
    expect(find.text('CONTRACT REF: CTR-1'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Approved Budget'), findsOneWidget);
    expect(find.text('Achieved KPIs'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    Future<void> reveal(Finder finder) =>
        tester.scrollUntilVisible(finder, 300, scrollable: scrollable);

    await reveal(find.text('Foundation'));
    expect(find.text('80%'), findsWidgets);

    await reveal(find.text('Objectives'));
    await reveal(find.text('Improve road access'));
    expect(find.text('Achieved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    await reveal(find.text('Location & Timeline'));
    expect(find.text('Lusaka'), findsNWidgets(2));

    await reveal(find.text('Site engineer'));
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('Jane Banda'), findsOneWidget);

    await reveal(find.text('Km paved'));
    expect(find.text('Pending'), findsOneWidget);

    await reveal(find.text('Cement purchase'));
    expect(find.text('MWK 1,500.00'), findsOneWidget);
    expect(find.text('Debit'), findsOneWidget);
    expect(find.text('First delivery'), findsOneWidget);
    expect(find.text('2026-03-01'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('MWK 2,500.00'), findsOneWidget);

    await reveal(find.text('No documents uploaded.'));
  });
}
