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
      'status': 'Completed',
      'progress': '80%',
      'remark': 'Poured',
      'supplier': 'ACME',
    });
    expect(record.title, 'Foundation');
    expect(record.subtitle, 'Poured');
    expect(record.done, isTrue);
    expect(record.percent, 80);
    expect(record.extras, {'Supplier': 'ACME'});
  });

  test('formats amounts with thousands separators', () {
    expect(formatAmount('1234567.5'), '1,234,567.50');
    expect(formatAmount('abc'), isNull);
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
