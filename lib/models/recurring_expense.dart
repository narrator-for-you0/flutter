import 'package:flutter/material.dart' show DateUtils;

/// How often a recurring expense repeats.
enum RecurringFrequency { daily, weekly, biweekly, monthly }

extension RecurringFrequencyLabel on RecurringFrequency {
  String get label {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Every 2 weeks';
      case RecurringFrequency.monthly:
        return 'Monthly';
    }
  }
}

/// An expense that logs itself on a schedule (e.g. ₱100 of load every week).
///
/// Occurrence dates are computed from [startDate] + [frequency], so there is
/// no drift. [lastGenerated] is the date of the newest occurrence that has
/// already been logged; everything after it (up to today) is "due".
class RecurringExpense {
  final int? id;
  final String title;
  final double amount;
  final String category; // subcategory label, like Expense.category
  final String paymentMethod;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate; // null = repeats forever
  final DateTime? lastGenerated;
  final bool active;

  const RecurringExpense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.paymentMethod = 'Cash',
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastGenerated,
    this.active = true,
  });

  RecurringExpense copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    String? paymentMethod,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? lastGenerated,
    bool? active,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      lastGenerated: lastGenerated ?? this.lastGenerated,
      active: active ?? this.active,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The n-th occurrence (0 = the start date itself).
  DateTime occurrence(int n) {
    final s = _dateOnly(startDate);
    switch (frequency) {
      case RecurringFrequency.daily:
        return DateTime(s.year, s.month, s.day + n);
      case RecurringFrequency.weekly:
        return DateTime(s.year, s.month, s.day + 7 * n);
      case RecurringFrequency.biweekly:
        return DateTime(s.year, s.month, s.day + 14 * n);
      case RecurringFrequency.monthly:
        final m = s.month - 1 + n;
        final year = s.year + m ~/ 12;
        final month = m % 12 + 1;
        // A rule that starts on the 31st lands on the last day of shorter months.
        final dim = DateUtils.getDaysInMonth(year, month);
        return DateTime(year, month, s.day > dim ? dim : s.day);
    }
  }

  /// Occurrences that are on or before [now], after [lastGenerated], and
  /// within the end date: i.e. what still needs to be logged. Capped to the
  /// most recent 120 so a very old rule can't flood the list.
  List<DateTime> dueOccurrences(DateTime now) {
    final today = _dateOnly(now);
    final last = lastGenerated == null ? null : _dateOnly(lastGenerated!);
    final end = endDate == null ? null : _dateOnly(endDate!);

    final out = <DateTime>[];
    for (var n = 0; n < 5000; n++) {
      final d = occurrence(n);
      if (d.isAfter(today)) break;
      if (end != null && d.isAfter(end)) break;
      if (last != null && !d.isAfter(last)) continue;
      out.add(d);
    }
    if (out.length > 120) return out.sublist(out.length - 120);
    return out;
  }

  /// The next date this will log on (today counts if it hasn't been logged
  /// yet), or null if the rule has ended.
  DateTime? nextOccurrence(DateTime now) {
    final today = _dateOnly(now);
    final last = lastGenerated == null ? null : _dateOnly(lastGenerated!);
    final end = endDate == null ? null : _dateOnly(endDate!);

    for (var n = 0; n < 5000; n++) {
      final d = occurrence(n);
      if (end != null && d.isAfter(end)) return null;
      if (d.isBefore(today)) continue;
      if (last != null && !d.isAfter(last)) continue;
      return d;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'paymentMethod': paymentMethod,
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'lastGenerated': lastGenerated?.toIso8601String(),
      'active': active ? 1 : 0,
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
      frequency: RecurringFrequency.values.firstWhere(
        (f) => f.name == map['frequency'],
        orElse: () => RecurringFrequency.weekly,
      ),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      lastGenerated: map['lastGenerated'] != null
          ? DateTime.parse(map['lastGenerated'] as String)
          : null,
      active: (map['active'] as int? ?? 1) == 1,
    );
  }
}
