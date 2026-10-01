import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';

/// Thrown when a file the person picked isn't a backup this app wrote, or is
/// one from a newer app version than this one understands. [message] is meant
/// to be shown to them verbatim.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// A recurring rule from the file, still paired with the id that the expenses
/// in that same file point at. [rule] itself has no id — the caller's database
/// assigns a new one on insert, and it reports back so [rule]'s expenses can be
/// repointed at it.
class ImportedRecurring {
  final RecurringExpense rule;

  /// The id this rule had in the database the backup came from.
  final int? backupId;

  const ImportedRecurring({required this.rule, this.backupId});
}

/// Everything a backup file holds, already turned back into models.
class BackupFile {
  /// When the backup was taken, or null if the file didn't say.
  final DateTime? exportedAt;

  /// The persisted settings blob (budgets, cycle, limits, quick add...).
  final Map<String, dynamic> settings;

  final List<Expense> expenses;
  final List<Income> income;
  final List<ImportedRecurring> recurring;

  /// Name / student info / avatar emoji. Null when the file has no profile —
  /// older backups only carried rows.
  final Map<String, dynamic>? profile;

  /// 'light' / 'dark' / 'system', or null to leave the theme alone.
  final String? themeMode;

  const BackupFile({
    this.exportedAt,
    required this.settings,
    required this.expenses,
    required this.income,
    required this.recurring,
    this.profile,
    this.themeMode,
  });

  bool get hasSettings => settings.isNotEmpty;

  /// How many rows of each kind the file holds. Shown before importing so the
  /// person knows what they're about to get.
  int get totalRows => expenses.length + income.length + recurring.length;
}

/// Reads and writes the app's backup file.
///
/// The format is one pretty-printed JSON document. Row ids are deliberately
/// left out: they only mean anything inside the database that produced them,
/// and forcing them back in would collide with whatever is already there.
/// [decode] therefore only ever returns rows with a null id — the caller
/// inserts them as new rows.
class BackupService {
  static const int formatVersion = 1;

  /// Identifies our files, so picking a random .json gives a clear message
  /// instead of a confusing parse error.
  static const String _kind = 'food-allowance-tracker-backup';

  static String fileNameFor(DateTime when) {
    return 'food_allowance_backup_${DateFormat('yyyy-MM-dd_HHmm').format(when)}.json';
  }

  /// Serialises everything into backup-file text.
  static String encode({
    required DateTime exportedAt,
    required Map<String, dynamic> settings,
    required List<Expense> expenses,
    required List<Income> income,
    required List<RecurringExpense> recurring,
    Map<String, dynamic>? profile,
    String? themeMode,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'kind': _kind,
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'themeMode': themeMode,
      'profile': profile,
      'settings': settings,
      'expenses': [for (final e in expenses) _expenseToJson(e)],
      'income': [for (final i in income) _incomeToJson(i)],
      'recurring': [for (final r in recurring) _recurringToJson(r)],
    });
  }

  /// Parses backup-file text. Throws [BackupFormatException] with something
  /// worth showing to the person if the file isn't one of ours.
  static BackupFile decode(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } catch (_) {
      throw const BackupFormatException(
        "That file isn't valid JSON, so it isn't a backup.",
      );
    }

    if (raw is! Map<String, dynamic>) {
      throw const BackupFormatException(
        'That file is not a backup from this app.',
      );
    }
    if (raw['kind'] != _kind) {
      throw const BackupFormatException(
        "That file isn't a backup from this app.",
      );
    }

    final version = (raw['formatVersion'] as num?)?.toInt() ?? 1;
    if (version > formatVersion) {
      throw BackupFormatException(
        'That backup came from a newer version of the app '
        '(format $version, this app understands $formatVersion). '
        'Update the app, then try again.',
      );
    }

    return BackupFile(
      exportedAt: DateTime.tryParse(raw['exportedAt'] as String? ?? ''),
      settings: _mapOf(raw['settings']),
      profile: raw['profile'] is Map<String, dynamic>
          ? raw['profile'] as Map<String, dynamic>
          : null,
      themeMode: raw['themeMode'] as String?,
      expenses: _listOf(raw['expenses']).map(_expenseFromJson).toList(),
      income: _listOf(raw['income']).map(_incomeFromJson).toList(),
      recurring: _listOf(raw['recurring']).map(_recurringFromJson).toList(),
    );
  }

  /// Writes [json] into the app's documents folder and hands back the file, so
  /// the caller can share it. Written outside the cache directory on purpose:
  /// the OS is free to wipe that at any time, and this file is the backup.
  static Future<File> writeToDocuments(String json, DateTime when) async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory(p.join(dir.path, 'backups'));
    if (!await backups.exists()) await backups.create(recursive: true);

    final file = File(p.join(backups.path, fileNameFor(when)));
    await file.writeAsString(json, flush: true);
    return file;
  }

  static Future<String> readFromFile(File file) => file.readAsString();

  // ---------------------------------------------------------------------------
  // Row <-> JSON. Field names match what the database stores, which keeps the
  // models' own toMap()/fromMap() usable for most of it.
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _expenseToJson(Expense e) {
    final m = e.toMap()..remove('id');
    return m;
  }

  static Map<String, dynamic> _incomeToJson(Income i) {
    final m = i.toMap()..remove('id');
    return m;
  }

  static Map<String, dynamic> _recurringToJson(RecurringExpense r) {
    // Keeps a placeholder id so the expenses that point at it can still be
    // matched up on import; the id is remapped to the new row's id there.
    return {
      'backupId': r.id,
      'title': r.title,
      'amount': r.amount,
      'category': r.category,
      'paymentMethod': r.paymentMethod,
      'frequency': r.frequency.name,
      'startDate': r.startDate.toIso8601String(),
      'endDate': r.endDate?.toIso8601String(),
      'lastGenerated': r.lastGenerated?.toIso8601String(),
      'active': r.active ? 1 : 0,
    };
  }

  static Expense _expenseFromJson(Map<String, dynamic> m) {
    return Expense.fromMap({
      ...m,
      'id': null, // never reuse the id from the file that produced it
      'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
      'fromSavings': (m['fromSavings'] as num?)?.toInt() ?? 0,
      'recurringId': (m['recurringId'] as num?)?.toInt(),
    });
  }

  static Income _incomeFromJson(Map<String, dynamic> m) {
    return Income.fromMap({
      ...m,
      'id': null,
      'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
      'note': m['note'] as String? ?? '',
    });
  }

  static ImportedRecurring _recurringFromJson(Map<String, dynamic> m) {
    return ImportedRecurring(
      backupId: (m['backupId'] as num?)?.toInt(),
      rule: RecurringExpense.fromMap({
        ...m,
        'id': null,
        'amount': (m['amount'] as num?)?.toDouble() ?? 0.0,
        'active': (m['active'] as num?)?.toInt() ?? 1,
      }),
    );
  }

  static Map<String, dynamic> _mapOf(Object? value) {
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOf(Object? value) {
    if (value is! List) return const [];
    return [
      for (final e in value)
        if (e is Map<String, dynamic>) e,
    ];
  }
}
