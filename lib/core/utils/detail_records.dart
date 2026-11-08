import 'dart:convert';

/// Decodes values that may arrive as JSON-encoded strings (possibly nested).
Object? decodeDetailValue(Object? value, [int depth = 0]) {
  if (value is! String) return value;
  final text = value.trim();
  if (text.isEmpty) return null;
  if (depth < 3 && (text.startsWith('[') || text.startsWith('{'))) {
    try {
      return decodeDetailValue(jsonDecode(text), depth + 1);
    } on FormatException {
      return text;
    }
  }
  return text;
}

/// Normalises a list / map / JSON-string / scalar value into a flat list.
List<Object?> detailItems(Object? value) {
  final decoded = decodeDetailValue(value);
  if (decoded == null) return const [];
  if (decoded is List) {
    return decoded
        .map(decodeDetailValue)
        .where((item) => item != null)
        .toList();
  }
  if (decoded is Map) {
    for (final key in const ['data', 'items', 'records']) {
      final nested = decoded[key];
      if (nested is List || nested is String) return detailItems(nested);
    }
    final values = decoded.values.map(decodeDetailValue).toList();
    if (values.isNotEmpty && values.every((v) => v is Map)) return values;
    return [decoded];
  }
  return [decoded];
}

class DetailRecord {
  const DetailRecord({
    required this.title,
    this.subtitle,
    this.projectObjective,
    this.user,
    this.status,
    this.type,
    this.amount,
    this.currency,
    this.date,
    this.percent,
    this.done,
    this.workflowStatus,
    this.extras = const {},
  });

  final String title;
  final String? subtitle;
  final String? projectObjective;
  final String? user;
  final String? status;
  final String? type;
  final String? amount;
  final String? currency;
  final String? date;
  final num? percent;
  final bool? done;

  /// Normalised publication state: `Draft` or `Published` (null if unknown).
  final String? workflowStatus;
  final Map<String, String> extras;

  static const _titleKeys = [
    'name',
    'title',
    'objective',
    'indicator',
    'kpi',
    'milestone',
    'employee_name',
    'full_name',
    'position',
    'role',
    'description',
  ];
  static const _subtitleKeys = [
    'remark',
    'remarks',
    'note',
    'notes',
    'description',
    'role',
    'position',
    'department',
    'email',
  ];
  static const _statusKeys = ['status', 'state'];
  static const _typeKeys = ['type', 'transaction_type', 'kind'];
  static const _amountKeys = [
    'amount',
    'value',
    'total',
    'cost',
    'budget',
    'quantity',
    'count',
  ];
  static const _dateKeys = [
    'date',
    'transaction_date',
    'due_date',
    'target_date',
    'end_date',
    'created_at',
    'updated_at',
  ];
  static const _percentKeys = [
    'progress',
    'completion',
    'completion_percentage',
    'percentage',
    'achievement_percentage',
  ];
  static const _doneKeys = [
    'is_achieved',
    'achieved',
    'is_completed',
    'completed',
  ];

  static const _workflowStatusKeys = [
    'workflow_status',
    'publication_status',
    'publish_status',
  ];
  static const _publishedFlagKeys = ['is_published', 'published'];

  static const _doneStatuses = {
    'completed',
    'complete',
    'achieved',
    'met',
    'done',
    'verified',
    'approved',
  };

  static String? _scalar(Object? value) {
    if (value == null || value is Map || value is List) return null;
    final text = value.toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return text.isEmpty ? null : text;
  }

  static num? _number(Object? value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.replaceAll(RegExp(r'[%\s,]'), ''));
    }
    return null;
  }

  static bool? _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (const {'true', 'yes', '1'}.contains(lower)) return true;
      if (const {'false', 'no', '0'}.contains(lower)) return false;
    }
    return null;
  }

  static String? _normalizeWorkflow(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'draft':
      case 'unpublished':
        return 'Draft';
      case 'published':
        return 'Published';
    }
    return null;
  }

  static String humanize(String key) {
    final spaced = key.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  factory DetailRecord.from(
    Object? item, {
    Set<String> hiddenKeys = const {},
    bool includeWorkflowStatus = false,
  }) {
    if (item is! Map) {
      return DetailRecord(title: _scalar(item) ?? '—');
    }
    final used = <String>{'id', ...hiddenKeys};

    String? pick(List<String> keys, {String? exclude}) {
      for (final key in keys) {
        final text = _scalar(item[key]);
        if (text != null && text != exclude) {
          used.add(key);
          return text;
        }
      }
      return null;
    }

    Object? pickRaw(List<String> keys) {
      for (final key in keys) {
        if (item[key] != null) {
          used.add(key);
          return item[key];
        }
      }
      return null;
    }

    String? workflowStatus;
    if (includeWorkflowStatus) {
      workflowStatus = _normalizeWorkflow(pick(_workflowStatusKeys));
      if (workflowStatus == null) {
        final published = _bool(pickRaw(_publishedFlagKeys));
        if (published != null) {
          workflowStatus = published ? 'Published' : 'Draft';
        }
      }
    }

    final title = pick(_titleKeys);
    final subtitle = pick(_subtitleKeys, exclude: title);
    final projectObjective = pick(const ['project_objective'], exclude: title);
    final user = pick(const ['user'], exclude: title);
    var status = pick(_statusKeys);
    if (includeWorkflowStatus && _normalizeWorkflow(status) != null) {
      workflowStatus ??= _normalizeWorkflow(status);
      status = null;
    }
    final type = pick(_typeKeys);
    final amount = pick(_amountKeys);
    final currency = pick(const ['currency']);
    final date = pick(_dateKeys);
    final percent = _number(pickRaw(_percentKeys));
    var done = _bool(pickRaw(_doneKeys));
    done ??= status == null
        ? null
        : _doneStatuses.contains(status.toLowerCase());

    final extras = <String, String>{};
    item.forEach((key, value) {
      final k = key.toString();
      if (used.contains(k)) return;
      final text = _scalar(value);
      if (text != null) extras[humanize(k)] = text;
    });

    final subtitleParts = <String>[
      if (projectObjective != null && projectObjective != subtitle)
        projectObjective,
      if (user != null && user != subtitle && user != projectObjective) user,
      if (subtitle != null) subtitle,
    ];

    return DetailRecord(
      title: title ?? subtitle ?? '—',
      subtitle: title == null || subtitleParts.isEmpty
          ? null
          : subtitleParts.join(' • '),
      projectObjective: projectObjective,
      user: user,
      status: status,
      type: type,
      amount: amount,
      currency: currency,
      date: date,
      percent: percent,
      done: done,
      workflowStatus: workflowStatus,
      extras: extras,
    );
  }
}

/// Formats numbers as `1,234.50`; returns null when [value] isn't numeric.
String? formatAmount(String value) {
  final number = num.tryParse(value.replaceAll(RegExp(r'[,\s]'), ''));
  if (number == null) return null;
  final fixed = number.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$whole.${parts[1]}';
}

/// Formats numeric values as compact units (`1.2K`, `3M`, `4.5B`, `1T`).
/// Returns null when [value] isn't numeric.
String? formatCompactAmount(String value) {
  final number = num.tryParse(value.replaceAll(RegExp(r'[,\s]'), ''));
  if (number == null) return null;

  final abs = number.abs();
  if (abs < 1000) return groupThousands(number.toString());

  const units = [
    (1000000000000, 'T'),
    (1000000000, 'B'),
    (1000000, 'M'),
    (1000, 'K'),
  ];

  for (final unit in units) {
    final divisor = unit.$1;
    final suffix = unit.$2;
    if (abs >= divisor) {
      final compact = number / divisor;
      final rounded = compact.toStringAsFixed(1);
      final normalized = rounded.endsWith('.0')
          ? rounded.substring(0, rounded.length - 2)
          : rounded;
      return '$normalized$suffix';
    }
  }

  return groupThousands(number.toString());
}

/// Adds thousands separators to every number in [value] (`MWK 1000` ->
/// `MWK 1,000`), leaving decimals and the rest of the text untouched.
String groupThousands(String value) {
  return value.replaceAllMapped(RegExp(r'\d+(\.\d+)?'), (match) {
    final number = match[0]!;
    final dot = number.indexOf('.');
    final whole = dot == -1 ? number : number.substring(0, dot);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return dot == -1 ? grouped : '$grouped${number.substring(dot)}';
  });
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a date value as `5 January 2026`; returns [value] unchanged when it
/// isn't a parseable date.
String formatLongDate(String value) {
  final date = DateTime.tryParse(value.trim());
  if (date == null) return value;
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

const _labelKeys = [
  'name',
  'title',
  'label',
  'full_name',
  'display_name',
  'department_name',
  'category_name',
  'description',
];

/// Extracts a clean display string from a scalar, a map (`name`/`title`/...),
/// a JSON-encoded string, or a list of those (comma-joined). Returns
/// [fallback] when nothing usable is found.
String displayText(Object? value, {String fallback = '—'}) {
  final decoded = decodeDetailValue(value);
  String? result;
  if (decoded is Map) {
    for (final key in _labelKeys) {
      final text = _plain(decoded[key]);
      if (text != null) {
        result = text;
        break;
      }
    }
  } else if (decoded is List) {
    final parts = decoded
        .map((item) => displayText(item, fallback: ''))
        .where((text) => text.isNotEmpty)
        .toList();
    result = parts.isEmpty ? null : parts.join(', ');
  } else {
    result = _plain(decoded);
  }
  return result ?? fallback;
}

String? _plain(Object? value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return text.isEmpty ? null : text;
}
