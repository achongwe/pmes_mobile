import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmes_mobile/core/utils/detail_records.dart';

void main() {
  test('decodes JSON-encoded strings, lists and wrapped maps', () {
    final transactions = [
      {'name': 'Cement', 'amount': 1500, 'type': 'debit'},
    ];
    expect(detailItems(jsonEncode(transactions)), hasLength(1));
    expect(detailItems(transactions), hasLength(1));
    expect(detailItems({'data': jsonEncode(transactions)}), hasLength(1));
    expect(
      detailItems({
        'a': {'name': 'One'},
        'b': {'name': 'Two'},
      }),
      hasLength(2),
    );
    expect(detailItems(''), isEmpty);
    expect(detailItems(null), isEmpty);
    expect(detailItems('Plain text'), ['Plain text']);
    expect(detailItems('[broken'), ['[broken']);
  });

  test('maps record fields and keeps unknown fields as extras', () {
    final record = DetailRecord.from({
      'id': 1,
      'name': 'Foundation',
      'project_objective': 'Improve road access',
      'user': 'John Banda',
      'status': 'Completed',
      'progress': '80%',
      'remark': 'Poured',
      'created_at': '2 hours ago',
      'supplier': 'ACME',
    });
    expect(record.title, 'Foundation');
    expect(record.subtitle, 'Improve road access • John Banda • Poured');
    expect(record.projectObjective, 'Improve road access');
    expect(record.user, 'John Banda');
    expect(record.date, '2 hours ago');
    expect(record.done, isTrue);
    expect(record.percent, 80);
    expect(record.extras, {'Supplier': 'ACME'});
  });

  test('formats amounts with thousands separators', () {
    expect(formatAmount('1234567.5'), '1,234,567.50');
    expect(formatAmount('abc'), isNull);
  });

  test('formats amounts with compact units up to trillions', () {
    expect(formatCompactAmount('1000'), '1K');
    expect(formatCompactAmount('1000000'), '1M');
    expect(formatCompactAmount('2500000000000'), '2.5T');
    expect(formatCompactAmount('999'), '999');
    expect(formatCompactAmount('abc'), isNull);
  });

  test('can hide technical ID fields from extras', () {
    final record = DetailRecord.from(
      {'name': 'KPI A', 'project_id': 'project-1', 'project_objective_id': 12},
      hiddenKeys: const {'project_id', 'project_objective_id'},
    );
    expect(record.extras.containsKey('Project id'), isFalse);
    expect(record.extras.containsKey('Project objective id'), isFalse);
  });

  test('derives Draft/Published workflow status when requested', () {
    DetailRecord parse(Map<String, dynamic> map) =>
        DetailRecord.from(map, includeWorkflowStatus: true);

    expect(
      parse({'name': 'A', 'workflow_status': 'published'}).workflowStatus,
      'Published',
    );
    expect(parse({'name': 'B', 'is_published': false}).workflowStatus, 'Draft');
    expect(parse({'name': 'C', 'is_published': 1}).workflowStatus, 'Published');

    final fromStatus = parse({'name': 'D', 'status': 'Draft'});
    expect(fromStatus.workflowStatus, 'Draft');
    expect(fromStatus.status, isNull);

    final withProgress = parse({
      'name': 'E',
      'workflow_status': 'draft',
      'status': 'Pending',
    });
    expect(withProgress.workflowStatus, 'Draft');
    expect(withProgress.status, 'Pending');

    expect(
      DetailRecord.from({'name': 'F', 'is_published': true}).workflowStatus,
      isNull,
    );
  });

  test('displayText extracts clean labels from complex values', () {
    expect(displayText({'id': 6, 'name': 'Roads', 'code': 'RD'}), 'Roads');
    expect(displayText(jsonEncode({'id': 1, 'title': 'Works'})), 'Works');
    expect(displayText('Transport'), 'Transport');
    expect(
      displayText([
        {'name': 'Lilongwe'},
        {'name': 'Zomba'},
      ]),
      'Lilongwe, Zomba',
    );
    expect(displayText({'id': 6}), '—');
    expect(displayText(null, fallback: 'No department'), 'No department');
    expect(displayText(''), '—');
  });
}
