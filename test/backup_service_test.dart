import 'package:flutter_app_project/models/expense.dart';
import 'package:flutter_app_project/models/income.dart';
import 'package:flutter_app_project/models/recurring_expense.dart';
import 'package:flutter_app_project/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final when = DateTime(2026, 10, 1, 9, 30);

  Expense expense({
    int? id,
    String title = 'Siomai Rice',
    double amount = 85,
    int? recurringId,
    bool fromSavings = false,
    DateTime? date,
  }) {
    return Expense(
      id: id,
      title: title,
      amount: amount,
      category: 'Lunch',
      date: date ?? DateTime(2026, 9, 28, 12, 15),
      paymentMethod: 'GCash',
      fromSavings: fromSavings,
      recurringId: recurringId,
    );
  }

  BackupFile roundTrip({
    List<Expense>? expenses,
    List<Income>? income,
    List<RecurringExpense>? recurring,
    Map<String, dynamic>? settings,
  }) {
    final json = BackupService.encode(
      exportedAt: when,
      settings:
          settings ??
          const {
            'cycleType': 'weekly',
            'budgets': {'x': 1.0},
          },
      expenses: expenses ?? const [],
      income: income ?? const [],
      recurring: recurring ?? const [],
      profile: const {
        'name': 'Alex',
        'studentInfo': 'BSIT',
        'avatarEmoji': '👨‍💻',
      },
      themeMode: 'dark',
    );
    return BackupService.decode(json);
  }

  group('BackupService', () {
    test('round-trips every row kind', () {
      final restored = roundTrip(
        expenses: [
          expense(id: 7, recurringId: 3),
          expense(id: 8, title: 'Milk Tea', amount: 45),
        ],
        income: [
          Income(
            id: 2,
            amount: 1500,
            note: 'Allowance',
            date: DateTime(2026, 9, 1),
          ),
        ],
        recurring: [
          RecurringExpense(
            id: 3,
            title: 'Weekly load',
            amount: 100,
            category: 'Load / Data',
            frequency: RecurringFrequency.weekly,
            startDate: DateTime(2026, 9, 1),
            lastGenerated: DateTime(2026, 9, 22),
            active: true,
          ),
          RecurringExpense(
            id: 4,
            title: 'Printing',
            amount: 50,
            category: 'Other',
            frequency: RecurringFrequency.monthly,
            startDate: DateTime(2026, 9, 5),
            endDate: DateTime(2026, 12, 20),
            active: false,
          ),
        ],
      );

      expect(restored.exportedAt, when);
      expect(restored.themeMode, 'dark');
      expect(restored.profile?['name'], 'Alex');
      expect(restored.hasSettings, isTrue);
      expect(restored.settings['cycleType'], 'weekly');

      expect(restored.expenses, hasLength(2));
      final siomai = restored.expenses.first;
      expect(siomai.title, 'Siomai Rice');
      expect(siomai.amount, 85.0);
      expect(siomai.date, DateTime(2026, 9, 28, 12, 15));
      expect(siomai.paymentMethod, 'GCash');
      expect(siomai.recurringId, 3);

      expect(restored.income.single.amount, 1500.0);
      expect(restored.income.single.note, 'Allowance');

      expect(restored.recurring, hasLength(2));
      final weekly = restored.recurring.first;
      expect(weekly.backupId, 3);
      expect(weekly.rule.title, 'Weekly load');
      expect(weekly.rule.frequency, RecurringFrequency.weekly);
      expect(weekly.rule.lastGenerated, DateTime(2026, 9, 22));
      expect(weekly.rule.active, isTrue);
      expect(restored.recurring.last.backupId, 4);
      expect(restored.recurring.last.rule.active, isFalse);
      expect(restored.recurring.last.rule.endDate, DateTime(2026, 12, 20));
    });

    test('strips row ids so a restore can\'t collide with existing rows', () {
      final restored = roundTrip(
        expenses: [expense(id: 7)],
        income: [Income(id: 2, amount: 500, date: DateTime(2026, 9, 1))],
        recurring: [
          RecurringExpense(
            title: 'Weekly load',
            amount: 100,
            category: 'Load / Data',
            frequency: RecurringFrequency.weekly,
            startDate: DateTime(2026, 9, 1),
          ),
        ],
      );

      expect(restored.expenses.single.id, isNull);
      expect(restored.income.single.id, isNull);
      expect(restored.recurring.single.rule.id, isNull);
    });

    test('reads a backup with no settings or profile (older file)', () {
      final json = BackupService.encode(
        exportedAt: when,
        settings: const {},
        expenses: [expense()],
        income: const [],
        recurring: const [],
      );
      final restored = BackupService.decode(json);

      expect(restored.hasSettings, isFalse);
      expect(restored.profile, isNull);
      expect(restored.themeMode, isNull);
      expect(restored.totalRows, 1);
    });

    test('rejects a file that isn\'t one of ours', () {
      expect(
        () => BackupService.decode('not json at all'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode('{"hello": "world"}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupService.decode('[1, 2, 3]'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('refuses a backup from a newer format instead of half-reading it', () {
      final json = BackupService.encode(
        exportedAt: when,
        settings: const {},
        expenses: [expense()],
        income: const [],
        recurring: const [],
      ).replaceFirst('"formatVersion": 1', '"formatVersion": 99');

      expect(
        () => BackupService.decode(json),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('file name is sortable and json-flavoured', () {
      final name = BackupService.fileNameFor(DateTime(2026, 10, 1, 14, 5));
      expect(name, 'food_allowance_backup_2026-10-01_1405.json');
    });
  });
}
