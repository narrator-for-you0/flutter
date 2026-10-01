import 'package:flutter_app_project/data/tips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayIndex', () {
    test('is deterministic for the same day', () {
      final a = dayIndex(DateTime(2026, 10, 2, 8, 30), 12);
      final b = dayIndex(DateTime(2026, 10, 2, 23, 59), 12);
      expect(a, b, reason: 'time of day must not affect the tip');
    });

    test('advances by exactly one per day', () {
      final start = DateTime(2026, 10, 2);
      for (var i = 0; i < 40; i++) {
        final today = dayIndex(start.add(Duration(days: i)), 12);
        final tomorrow = dayIndex(start.add(Duration(days: i + 1)), 12);
        expect(tomorrow, (today + 1) % 12);
      }
    });

    test('stays in range and wraps', () {
      for (var i = 0; i < 400; i++) {
        final index = dayIndex(DateTime(2026, 1, 1).add(Duration(days: i)), 12);
        expect(index, inInclusiveRange(0, 11));
      }
    });

    test('reaches every tip across one full cycle', () {
      final seen = <int>{};
      final start = DateTime(2026, 10, 2);
      for (var i = 0; i < 12; i++) {
        seen.add(dayIndex(start.add(Duration(days: i)), 12));
      }
      expect(seen.length, 12);
    });

    test('offset shifts the index without changing the step', () {
      final day = DateTime(2026, 10, 2);
      expect(dayIndex(day, 12, offset: 5), (dayIndex(day, 12) + 5) % 12);
      final a = dayIndex(day, 12, offset: 5);
      final b = dayIndex(day.add(const Duration(days: 1)), 12, offset: 5);
      expect(b, (a + 1) % 12);
    });

    test('does not jump a day across a month boundary', () {
      final before = dayIndex(DateTime(2026, 10, 31), 12);
      final after = dayIndex(DateTime(2026, 11, 1), 12);
      expect(after, (before + 1) % 12);
    });

    test('does not jump a day across a year boundary', () {
      final before = dayIndex(DateTime(2026, 12, 31), 12);
      final after = dayIndex(DateTime(2027, 1, 1), 12);
      expect(after, (before + 1) % 12);
    });

    test('handles dates before the epoch without negative indexing', () {
      final index = dayIndex(DateTime(2020, 1, 1), 12);
      expect(index, inInclusiveRange(0, 11));
    });

    test('rejects an empty pool instead of crashing at the call site', () {
      expect(() => dayIndex(DateTime(2026, 10, 2), 0), throwsArgumentError);
    });
  });

  group('pickTip', () {
    const pool = [Tip('A', 'a'), Tip('B', 'b'), Tip('C', 'c')];
    const urgent = [Tip('U1', 'u1'), Tip('U2', 'u2')];
    final day = DateTime(2026, 10, 2);

    test('rotates one step per day', () {
      final titles = [
        for (var i = 0; i < 3; i++)
          pickTip(
            pool: pool,
            urgent: urgent,
            now: day.add(Duration(days: i)),
            isUrgent: false,
          ).title,
      ];
      expect(titles.toSet().length, 3, reason: 'each day should differ');
    });

    test('draws from the urgent pool and never from pool when urgent', () {
      for (var i = 0; i < 10; i++) {
        final tip = pickTip(
          pool: pool,
          urgent: urgent,
          now: day.add(Duration(days: i)),
          isUrgent: true,
        );
        expect(tip.title, startsWith('U'));
      }
    });

    test('the urgent pool also rotates rather than sticking on one', () {
      final titles = {
        for (var i = 0; i < 2; i++)
          pickTip(
            pool: pool,
            urgent: urgent,
            now: day.add(Duration(days: i)),
            isUrgent: true,
          ).title,
      };
      expect(titles.length, 2);
    });

    test('falls back to the normal pool when there are no urgent tips', () {
      final tip = pickTip(
        pool: pool,
        urgent: const [],
        now: day,
        isUrgent: true,
      );
      expect(pool, contains(tip));
    });
  });

  group('isBudgetUrgent', () {
    test('is false with plenty of headroom', () {
      expect(isBudgetUrgent(spent: 500, budget: 2000), isFalse);
    });

    test('is false just under the threshold', () {
      expect(isBudgetUrgent(spent: 1799, budget: 2000), isFalse);
    });

    test('is true exactly at the threshold', () {
      expect(isBudgetUrgent(spent: 1800, budget: 2000), isTrue);
    });

    test('is true past the threshold', () {
      expect(isBudgetUrgent(spent: 1900, budget: 2000), isTrue);
    });

    test('is true when spending has reached the budget', () {
      expect(isBudgetUrgent(spent: 2000, budget: 2000), isTrue);
    });

    test('is true when overspending', () {
      expect(isBudgetUrgent(spent: 2500, budget: 2000), isTrue);
    });

    test('is false with no budget set', () {
      expect(isBudgetUrgent(spent: 9999, budget: 0), isFalse);
      expect(isBudgetUrgent(spent: 100, budget: -50), isFalse);
    });

    test('agrees with the documented threshold constant', () {
      expect(
        isBudgetUrgent(spent: kUrgentBudgetFraction * 1000, budget: 1000),
        isTrue,
      );
    });
  });

  group('copy pools', () {
    test('saving and campus pools are long enough not to repeat quickly', () {
      expect(savingTips.length, greaterThanOrEqualTo(10));
      expect(campusTips.length, greaterThanOrEqualTo(10));
      expect(savingUrgentTips, isNotEmpty);
      expect(campusUrgentTips, isNotEmpty);
    });

    test('every tip has a lead-in and a body', () {
      for (final pool in [
        savingTips,
        campusTips,
        savingUrgentTips,
        campusUrgentTips,
      ]) {
        for (final tip in pool) {
          expect(tip.title.trim(), isNotEmpty);
          expect(tip.body.trim(), isNotEmpty);
          expect(
            tip.title.endsWith(': '),
            isFalse,
            reason: 'the widget adds the colon; copy should not carry one',
          );
        }
      }
    });

    test('the original tips survived the rewrite', () {
      expect(
        savingTips.map((t) => t.title),
        contains('Refill, don\'t repurchase'),
      );
      expect(
        campusTips.map((t) => t.title),
        contains('Silog & canteen combos'),
      );
      expect(campusTips.map((t) => t.title), contains('Merienda limit'));
    });

    test('no duplicate tips within a pool', () {
      for (final pool in [
        savingTips,
        campusTips,
        savingUrgentTips,
        campusUrgentTips,
      ]) {
        final titles = pool.map((t) => t.title).toList();
        expect(titles.toSet().length, titles.length);
      }
    });

    test('the two pools never show the same tip on the same day', () {
      final start = DateTime(2026, 10, 2);
      for (var i = 0; i < 12; i++) {
        final now = start.add(Duration(days: i));
        final saving = pickTip(
          pool: savingTips,
          urgent: savingUrgentTips,
          now: now,
          isUrgent: false,
        );
        final campus = pickTip(
          pool: campusTips,
          urgent: campusUrgentTips,
          now: now,
          isUrgent: false,
          offset: 5,
        );
        expect(saving.title, isNot(campus.title));
      }
    });
  });
}
