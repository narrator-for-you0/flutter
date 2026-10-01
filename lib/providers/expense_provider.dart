import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../models/income.dart';
import '../models/expense_category.dart';
import '../models/recurring_expense.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/reminder_services.dart';
import '../utils/format.dart';

/// How often the allowance/budget period repeats. `monthly` keeps today's
/// behavior (a calendar month); `weekly`/`biweekly` are rolling windows
/// anchored to [ExpenseProvider.cycleAnchor].
enum AllowanceCycleType { monthly, weekly, biweekly }

// Model for Customizable Quick Add Shortcuts
class QuickAddItem {
  final String id;
  final String title;
  final double amount;
  final String emoji;
  final String category;

  QuickAddItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.emoji,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'emoji': emoji,
    'category': category,
  };

  factory QuickAddItem.fromJson(Map<String, dynamic> json) => QuickAddItem(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    emoji: json['emoji'] as String,
    category: json['category'] as String,
  );
}

/// Result of adding an expense, used to decide whether to show the
/// "daily limit exceeded" pop-up.
class LimitCheck {
  final DateTime day; // the day the expense was logged on
  final double limit; // that day's limit
  final double dayTotal; // that day's total AFTER this expense
  final bool wasOver; // day was already over the limit BEFORE this expense

  /// Category limits this expense pushed over (empty most of the time).
  final List<CategoryLimitHit> categoryHits;

  const LimitCheck({
    required this.day,
    required this.limit,
    required this.dayTotal,
    required this.wasOver,
    this.categoryHits = const [],
  });

  bool get isOver => dayTotal > limit;

  /// This expense is the one that pushed the day over the limit.
  bool get crossed => isOver && !wasOver;

  double get overBy => isOver ? dayTotal - limit : 0.0;
}

/// Category limits are stored under these keys. The prefix keeps a type
/// ('Other') apart from a subcategory that happens to share its name.
String typeBudgetKey(String typeName) => 'type:$typeName';
String subBudgetKey(String label) => 'sub:$label';

/// A category limit that a just-saved expense pushed over.
class CategoryLimitHit {
  final String label; // 'Food' or 'Coffee'
  final String emoji;
  final double limit;
  final double total; // the category's total for the period, after the expense

  const CategoryLimitHit({
    required this.label,
    required this.emoji,
    required this.limit,
    required this.total,
  });

  double get overBy => total - limit;
}

/// One category limit and how much of it is used this period (for the Budget tab).
class CategoryBudgetStatus {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  final double limit;
  final double spent;

  const CategoryBudgetStatus({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.limit,
    required this.spent,
  });

  double get ratio => limit > 0 ? spent / limit : 0.0;
  bool get isOver => spent > limit;
  double get remaining => limit - spent;
}

/// One finished allowance cycle and what was left of it.
class SavingsCycle {
  final DateTime start;
  final DateTime end;

  /// budget + income - spent (- carried shortfall). Negative = ended over.
  final double leftover;

  const SavingsCycle({
    required this.start,
    required this.end,
    required this.leftover,
  });

  /// The part that became savings.
  double get saved => leftover > 0 ? leftover : 0.0;
}

/// What an import actually did, so the UI can say it out loud instead of
/// claiming everything was restored.
class BackupImportSummary {
  final int expensesAdded;
  final int expensesSkipped;
  final int incomeAdded;
  final int incomeSkipped;
  final int recurringAdded;
  final int recurringSkipped;

  /// True when the backup's budgets/limits/quick add replaced the current ones.
  final bool settingsApplied;

  const BackupImportSummary({
    required this.expensesAdded,
    required this.expensesSkipped,
    required this.incomeAdded,
    required this.incomeSkipped,
    required this.recurringAdded,
    required this.recurringSkipped,
    this.settingsApplied = false,
  });

  int get rowsAdded => expensesAdded + incomeAdded + recurringAdded;
  int get rowsSkipped => expensesSkipped + incomeSkipped + recurringSkipped;
}

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  List<Income> _income = [];

  // Per-cycle budgets. For a `monthly` cycle the key is 'yyyy-MM' (exactly
  // what this used to be keyed by, so existing saved budgets keep working
  // unchanged); for `weekly`/`biweekly` the key is the cycle's start date
  // ('yyyy-MM-dd'). Falls back to _defaultBudget for any period that
  // hasn't had a budget explicitly set.
  final Map<String, double> _cycleBudgets = {};
  static const double _defaultBudget = 6000.0;
  bool _isLoading = false;

  // End-of-day "log your spending" reminder (off until the person enables it)
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  // ---------------------------------------------------------------------------
  // Allowance cycle (monthly / weekly / biweekly)
  // ---------------------------------------------------------------------------
  AllowanceCycleType _cycleType = AllowanceCycleType.monthly;

  // Anchors the recurring boundary: for weekly/biweekly, its weekday is the
  // day cycles start on, and (for biweekly) its exact date decides which of
  // the two weeks is "week 1". Irrelevant while _cycleType is monthly.
  DateTime _cycleAnchor = DateTime.now();

  // "Start fresh" marker for carryover. Cycles that start on or before this
  // date never inherit a shortfall from earlier cycles. null = never reset.
  DateTime? _carryoverFreshFrom;

  // Daily limit. null = automatic (that month's budget / days in the month).
  double? _customDailyLimit;

  // "Already over when you opened the app" banner
  bool _initialLoadDone = false;
  bool _launchBannerArmed = false;
  bool _launchBannerDismissed = false;

  // Category limits per period, keyed by typeBudgetKey()/subBudgetKey().
  final Map<String, double> _categoryBudgets = {};

  // Recurring expenses (auto-logged on a schedule).
  List<RecurringExpense> _recurring = [];
  bool _generatingRecurring = false;

  // End-of-period summary: start date ('yyyy-MM-dd') of the last finished
  // period we already told the person about.
  bool _cycleSummaryEnabled = true;
  String? _lastSummaryCycle;

  String _monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);

  // Initial Quick Add Items State
  final List<QuickAddItem> _quickAddItems = [
    QuickAddItem(
      id: '1',
      title: 'Siomai Rice',
      amount: 85.0,
      emoji: '🍜',
      category: 'Lunch',
    ),
    QuickAddItem(
      id: '2',
      title: 'Egg & Rice',
      amount: 80.0,
      emoji: '🍳',
      category: 'Breakfast',
    ),
    QuickAddItem(
      id: '3',
      title: 'Milk Tea',
      amount: 45.0,
      emoji: '🧋',
      category: 'Drinks',
    ),
  ];

  // Getters
  List<Expense> get expenses => _expenses;
  double get monthlyBudget => getBudgetForMonth(DateTime.now());
  bool get isLoading => _isLoading;
  List<QuickAddItem> get quickAddItems => _quickAddItems;

  AllowanceCycleType get cycleType => _cycleType;
  DateTime get cycleAnchor => _cycleAnchor;

  /// Change the allowance cycle. Pass [anchor] when switching to
  /// weekly/biweekly (its weekday becomes the cycle's start weekday; for
  /// biweekly, its exact date also decides which week is "week 1"). Not
  /// needed for monthly, which always uses calendar-month bounds.
  void setAllowanceCycle(AllowanceCycleType type, {DateTime? anchor}) {
    _cycleType = type;
    if (anchor != null) {
      _cycleAnchor = DateTime(anchor.year, anchor.month, anchor.day);
    }
    notifyListeners();
    _saveSettings();
  }

  DateTime _rollingCycleStart(DateTime day, DateTime anchor, int periodDays) {
    final d = DateTime(day.year, day.month, day.day);
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    final daysSinceAnchor = d.difference(a).inDays;
    final cyclesElapsed = (daysSinceAnchor / periodDays).floor();
    return a.add(Duration(days: cyclesElapsed * periodDays));
  }

  /// Pure version of [currentCycleStart] that takes an explicit
  /// type/anchor instead of the persisted ones — used by the budget editor
  /// to preview a cycle before the person saves it.
  DateTime cycleStartFor(
    AllowanceCycleType type,
    DateTime anchor,
    DateTime reference,
  ) {
    switch (type) {
      case AllowanceCycleType.monthly:
        return DateTime(reference.year, reference.month, 1);
      case AllowanceCycleType.weekly:
        return _rollingCycleStart(reference, anchor, 7);
      case AllowanceCycleType.biweekly:
        return _rollingCycleStart(reference, anchor, 14);
    }
  }

  /// Pure version of [currentCycleEnd] for an explicit type + cycle start.
  DateTime cycleEndFor(AllowanceCycleType type, DateTime cycleStart) {
    switch (type) {
      case AllowanceCycleType.monthly:
        final daysInMonth = DateUtils.getDaysInMonth(
          cycleStart.year,
          cycleStart.month,
        );
        return DateTime(cycleStart.year, cycleStart.month, daysInMonth);
      case AllowanceCycleType.weekly:
        return cycleStart.add(const Duration(days: 6));
      case AllowanceCycleType.biweekly:
        return cycleStart.add(const Duration(days: 13));
    }
  }

  /// Start of the allowance cycle [day] falls in, using the active cycle
  /// type. For `monthly` this is just the 1st of that month — i.e.
  /// **today's exact behavior** — so nothing changes unless the person
  /// switches to weekly/biweekly.
  DateTime currentCycleStart(DateTime day) =>
      cycleStartFor(_cycleType, _cycleAnchor, day);

  /// End (inclusive) of the allowance cycle [day] falls in.
  DateTime currentCycleEnd(DateTime day) =>
      cycleEndFor(_cycleType, currentCycleStart(day));

  /// How many days are in the cycle [day] falls in.
  int cycleLengthInDays(DateTime day) {
    switch (_cycleType) {
      case AllowanceCycleType.monthly:
        final start = currentCycleStart(day);
        return DateUtils.getDaysInMonth(start.year, start.month);
      case AllowanceCycleType.weekly:
        return 7;
      case AllowanceCycleType.biweekly:
        return 14;
    }
  }

  /// Storage key for a cycle's budget. For `monthly` this is 'yyyy-MM' —
  /// identical to the key this used to always use — so budgets saved
  /// before this feature existed keep resolving correctly.
  String budgetKeyFor(AllowanceCycleType type, DateTime cycleStart) {
    if (type == AllowanceCycleType.monthly) return _monthKey(cycleStart);
    return DateFormat('yyyy-MM-dd').format(cycleStart);
  }

  /// Budget saved for a cycle key. A cycle with no budget of its own inherits
  /// the nearest earlier one you set (or, if none, the earliest later one),
  /// so a budget you set once keeps applying until you change it. Falls back
  /// to the default only if you've never set one for this cycle type.
  double budgetForCycleKey(String key) {
    final exact = _cycleBudgets[key];
    if (exact != null) return exact;

    String? before;
    String? after;
    for (final k in _cycleBudgets.keys) {
      if (k.length != key.length) continue; // monthly vs weekly key formats
      if (k.compareTo(key) < 0) {
        if (before == null || k.compareTo(before) > 0) before = k;
      } else {
        if (after == null || k.compareTo(after) < 0) after = k;
      }
    }
    final pick = before ?? after;
    return pick != null ? _cycleBudgets[pick]! : _defaultBudget;
  }

  /// Budget for the cycle [day] falls in (using the active cycle type).
  double getBudgetForCycle(DateTime day) {
    return budgetForCycleKey(budgetKeyFor(_cycleType, currentCycleStart(day)));
  }

  void updateBudgetForCycle(
    double newBudget,
    AllowanceCycleType type,
    DateTime cycleStart,
  ) {
    _cycleBudgets[budgetKeyFor(type, cycleStart)] = newBudget;
    notifyListeners();
    _saveSettings();
  }

  /// Total spent within the cycle [day] falls in (using the active cycle
  /// type) — unlike [totalSpentForMonth], this respects weekly/biweekly
  /// cycles instead of always being a calendar month.
  double totalSpentForCycle(DateTime day) {
    final start = currentCycleStart(day);
    final endExclusive = currentCycleEnd(day).add(const Duration(days: 1));
    return _expenses
        .where(
          (e) =>
              !e.fromSavings &&
              !e.date.isBefore(start) &&
              e.date.isBefore(endExclusive),
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Total income received within the cycle [day] falls in.
  double totalIncomeForCycle(DateTime day) {
    final start = currentCycleStart(day);
    final endExclusive = currentCycleEnd(day).add(const Duration(days: 1));
    return _income
        .where((i) => !i.date.isBefore(start) && i.date.isBefore(endExclusive))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  /// What you can still spend this cycle against your budget target:
  /// budget + income received this cycle - spent this cycle so far, minus
  /// any shortfall carried over from the previous cycle (see
  /// [carryoverInto]). This is the budget-aware number — it can differ from
  /// [currentBalance] (your real cash on hand) on purpose.
  double availableThisCycle(DateTime day) {
    return getBudgetForCycle(day) +
        totalIncomeForCycle(day) -
        totalSpentForCycle(day) +
        carryoverInto(day);
  }

  // ---------------------------------------------------------------------------
  // Carryover: a cycle that ends over budget lowers the next cycle's budget.
  // Only shortfalls carry (an unspent surplus does not), and a chain of bad
  // cycles keeps carrying until you have a cycle that ends at or under
  // budget, or you tap "Start fresh".
  // ---------------------------------------------------------------------------
  DateTime? get carryoverFreshFrom => _carryoverFreshFrom;

  /// The shortfall (zero or negative) carried into the cycle [day] falls in.
  double carryoverInto(DateTime day) =>
      _carryoverInto(currentCycleStart(day), 0);

  double _carryoverInto(DateTime cycleStart, int depth) {
    if (depth > 52) return 0.0; // safety net against runaway chains

    final fresh = _carryoverFreshFrom;
    if (fresh != null && !cycleStart.isAfter(fresh)) return 0.0;

    final first = firstExpenseDate;
    if (first == null) return 0.0;

    final prevDay = DateTime(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day - 1,
    );
    // Nothing was tracked before you started logging, so nothing to carry.
    if (currentCycleEnd(prevDay).isBefore(first)) return 0.0;

    final prevAvailable =
        getBudgetForCycle(prevDay) +
        totalIncomeForCycle(prevDay) -
        totalSpentForCycle(prevDay) +
        _carryoverInto(currentCycleStart(prevDay), depth + 1);

    return prevAvailable < 0 ? prevAvailable : 0.0;
  }

  /// Forgive everything carried into the current cycle: from now on, only
  /// this cycle's own result can carry forward. Returns the previous marker
  /// so the caller can offer an undo via [restoreCarryoverFreshFrom].
  DateTime? startFreshCarryover() {
    final previous = _carryoverFreshFrom;
    _carryoverFreshFrom = currentCycleStart(DateTime.now());
    notifyListeners();
    _saveSettings();
    return previous;
  }

  void restoreCarryoverFreshFrom(DateTime? value) {
    _carryoverFreshFrom = value;
    notifyListeners();
    _saveSettings();
  }

  // ---------------------------------------------------------------------------
  // Savings: unspent budget from FINISHED cycles. The current cycle doesn't
  // count yet (you can still spend it). Expenses flagged `fromSavings` draw
  // this balance down instead of counting against the budget.
  // ---------------------------------------------------------------------------

  /// The first cycle that counts toward savings: the later of your first
  /// logged expense and the first cycle you explicitly set a budget for
  /// (so the untouched default budget can't create phantom savings).
  /// Null if you've never set a budget for the active cycle type.
  DateTime? _savingsStart() {
    final first = firstExpenseDate;
    if (first == null) return null;

    final wantedLength = _cycleType == AllowanceCycleType.monthly ? 7 : 10;
    String? earliestKey;
    for (final k in _cycleBudgets.keys) {
      if (k.length != wantedLength) continue;
      if (earliestKey == null || k.compareTo(earliestKey) < 0) earliestKey = k;
    }
    if (earliestKey == null) return null;

    final budgetDate = wantedLength == 7
        ? DateTime.parse('$earliestKey-01')
        : DateTime.parse(earliestKey);

    final firstCycle = currentCycleStart(first);
    final budgetCycle = currentCycleStart(budgetDate);
    return budgetCycle.isAfter(firstCycle) ? budgetCycle : firstCycle;
  }

  /// True once you've set a budget, i.e. savings tracking can begin.
  bool get canTrackSavings => _savingsStart() != null;

  /// Every finished cycle since savings tracking began, oldest first. A
  /// cycle's `leftover` is budget + income - spent (minus any carried-over
  /// shortfall); only a positive leftover becomes savings.
  List<SavingsCycle> savingsHistory() {
    final start = _savingsStart();
    if (start == null) return [];

    final todayStart = currentCycleStart(DateTime.now());
    final out = <SavingsCycle>[];
    var cursor = start;
    var carry = _carryoverInto(start, 0);
    var guard = 0;

    while (cursor.isBefore(todayStart) && guard++ < 600) {
      final end = currentCycleEnd(cursor);
      final fresh = _carryoverFreshFrom;
      if (fresh != null && !cursor.isAfter(fresh)) carry = 0.0;

      final leftover =
          getBudgetForCycle(cursor) +
          totalIncomeForCycle(cursor) -
          totalSpentForCycle(cursor) +
          carry;
      out.add(SavingsCycle(start: cursor, end: end, leftover: leftover));

      carry = leftover < 0 ? leftover : 0.0;
      cursor = DateTime(end.year, end.month, end.day + 1);
    }
    return out;
  }

  /// Everything unspent from finished cycles.
  double get totalSavingsEarned =>
      savingsHistory().fold(0.0, (sum, c) => sum + c.saved);

  /// Expenses paid out of savings, newest first.
  List<Expense> get savingsWithdrawals {
    final list = _expenses.where((e) => e.fromSavings).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  double get totalSavingsSpent => _expenses
      .where((e) => e.fromSavings)
      .fold(0.0, (sum, e) => sum + e.amount);

  /// What you can still spend from savings (never negative).
  double get savingsBalance {
    final b = totalSavingsEarned - totalSavingsSpent;
    return b < 0 ? 0.0 : b;
  }

  // ---------------------------------------------------------------------------
  // Legacy calendar-month budget API (kept so existing call sites — the
  // Home tab's quick budget edit, etc. — keep compiling unchanged). These
  // now resolve through the cycle system above, so for the default
  // `monthly` cycle they behave exactly as before.
  // ---------------------------------------------------------------------------
  double getBudgetForMonth(DateTime month) => getBudgetForCycle(month);

  void updateBudget(double newBudget, {DateTime? month}) {
    final day = month ?? DateTime.now();
    updateBudgetForCycle(newBudget, _cycleType, currentCycleStart(day));
  }

  // Calculated Metrics (scoped to the current month)
  double totalSpentForMonth(DateTime month) {
    return _expenses
        .where(
          (e) =>
              !e.fromSavings &&
              e.date.year == month.year &&
              e.date.month == month.month,
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Spent in the CURRENT budget cycle (month, week or two weeks, whichever
  /// the person chose). Pairs with [monthlyBudget], which is also per-cycle;
  /// the old calendar-month total made Home disagree with the Budget tab on
  /// weekly/biweekly cycles.
  double get totalSpent => totalSpentForCycle(DateTime.now());

  double get remainingBudget {
    final remaining = monthlyBudget - totalSpent;
    return remaining < 0 ? 0 : remaining;
  }

  double get budgetPercentage {
    if (monthlyBudget == 0) return 0.0;
    final pct = totalSpent / monthlyBudget;
    return pct > 1.0 ? 1.0 : pct;
  }

  int get budgetPercentageInt => (budgetPercentage * 100).toInt();

  // ---------------------------------------------------------------------------
  // Daily limit
  // ---------------------------------------------------------------------------
  double? get customDailyLimit => _customDailyLimit;

  /// Limit for a given day: the custom limit if one is set, otherwise that
  /// month's budget spread evenly across its days.
  /// Today's (or any day's) spending ceiling. Accounts for income already
  /// received this cycle: a raise that lands mid-cycle raises the
  /// *remaining* days' limit, not just the cycle's end total. Spending
  /// logged ON [day] itself isn't counted here (only income is), so the
  /// limit doesn't shrink under you as you log today's own expenses.
  double dailyLimitFor(DateTime day) {
    if (_customDailyLimit != null) return _customDailyLimit!;

    final cycleStart = currentCycleStart(day);
    final cycleEnd = currentCycleEnd(day);
    final d = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(d.year, d.month, d.day, 23, 59, 59);

    final budget = getBudgetForCycle(day) + _carryoverInto(cycleStart, 0);
    final incomeThroughDay = _income
        .where((i) => !i.date.isBefore(cycleStart) && !i.date.isAfter(dayEnd))
        .fold(0.0, (sum, i) => sum + i.amount);
    final spentBeforeDay = _expenses
        .where(
          (e) =>
              !e.fromSavings &&
              !e.date.isBefore(cycleStart) &&
              e.date.isBefore(d),
        )
        .fold(0.0, (sum, e) => sum + e.amount);

    final daysRemaining = (cycleEnd.difference(d).inDays + 1).clamp(1, 999);
    final remaining = budget + incomeThroughDay - spentBeforeDay;
    final perDay = remaining / daysRemaining;
    // A big carried-over shortfall can push this below zero; floor it at 0
    // ("nothing is safe to spend today") instead of a negative limit.
    return perDay < 0 ? 0.0 : perDay;
  }

  double get dailyLimit => dailyLimitFor(DateTime.now());

  /// Pass null (or 0) to go back to the automatic limit.
  void setDailyLimit(double? value) {
    _customDailyLimit = (value != null && value > 0) ? value : null;
    notifyListeners();
    _saveSettings();
  }

  double totalSpentOn(DateTime day) {
    return _expenses
        .where((e) => !e.fromSavings && DateUtils.isSameDay(e.date, day))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get todaySpent => totalSpentOn(DateTime.now());

  bool get isOverDailyLimitToday => todaySpent > dailyLimit;

  /// Banner shown only if the app was opened already over today's limit.
  bool get showLimitBanner =>
      _launchBannerArmed && !_launchBannerDismissed && isOverDailyLimitToday;

  void dismissLimitBanner() {
    _launchBannerDismissed = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Category budgets (caps per major type or subcategory, per period)
  // ---------------------------------------------------------------------------
  Map<String, double> get categoryBudgets => Map.unmodifiable(_categoryBudgets);

  double? categoryLimitFor(String key) => _categoryBudgets[key];

  /// Save several limits at once. A null or zero value removes that limit.
  void setCategoryBudgets(Map<String, double?> values) {
    values.forEach((key, value) {
      if (value == null || value <= 0) {
        _categoryBudgets.remove(key);
      } else {
        _categoryBudgets[key] = value;
      }
    });
    notifyListeners();
    _saveSettings();
  }

  bool _matchesBudgetKey(Expense e, String key) {
    if (key.startsWith('type:')) return e.type == key.substring(5);
    if (key.startsWith('sub:')) return e.category == key.substring(4);
    return false;
  }

  /// Spent on one category within the cycle [day] falls in (savings-funded
  /// expenses don't count, same as the overall budget).
  double categorySpentForCycle(String key, DateTime day) {
    final start = currentCycleStart(day);
    final endExclusive = currentCycleEnd(day).add(const Duration(days: 1));
    return _expenses
        .where(
          (e) =>
              !e.fromSavings &&
              _matchesBudgetKey(e, key) &&
              !e.date.isBefore(start) &&
              e.date.isBefore(endExclusive),
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Every limit that is set, with this period's spending, most-used first.
  List<CategoryBudgetStatus> categoryBudgetStatuses(DateTime day) {
    final out = <CategoryBudgetStatus>[];
    for (final t in CategoryData.types) {
      final typeKey = typeBudgetKey(t.name);
      final typeLimit = _categoryBudgets[typeKey];
      if (typeLimit != null) {
        out.add(
          CategoryBudgetStatus(
            key: typeKey,
            label: t.name,
            emoji: t.emoji,
            color: t.color,
            limit: typeLimit,
            spent: categorySpentForCycle(typeKey, day),
          ),
        );
      }
      for (final s in t.subCategories) {
        final subKey = subBudgetKey(s.label);
        final subLimit = _categoryBudgets[subKey];
        if (subLimit != null) {
          out.add(
            CategoryBudgetStatus(
              key: subKey,
              label: s.label,
              emoji: s.emoji,
              color: s.color,
              limit: subLimit,
              spent: categorySpentForCycle(subKey, day),
            ),
          );
        }
      }
    }
    out.sort((a, b) => b.ratio.compareTo(a.ratio));
    return out;
  }

  /// Limits that saving [e] pushes over (it must be the expense that CROSSES
  /// the line, not one that was already over). Call BEFORE [e] is added to
  /// the list; pass [original] when editing so it isn't counted twice.
  List<CategoryLimitHit> _categoryHits(Expense e, {Expense? original}) {
    if (e.fromSavings || _categoryBudgets.isEmpty) return const [];

    final start = currentCycleStart(e.date);
    final endExclusive = currentCycleEnd(e.date).add(const Duration(days: 1));
    bool inCycle(Expense x) =>
        !x.date.isBefore(start) && x.date.isBefore(endExclusive);
    bool isOriginal(Expense x) =>
        original != null &&
        (identical(x, original) ||
            (original.id != null && x.id == original.id));

    final hits = <CategoryLimitHit>[];
    final candidates = [
      (
        typeBudgetKey(e.type),
        CategoryData.typeByName(e.type).name,
        CategoryData.typeByName(e.type).emoji,
      ),
      (subBudgetKey(e.category), e.category, CategoryData.emojiFor(e.category)),
    ];
    for (final (key, label, emoji) in candidates) {
      final cap = _categoryBudgets[key];
      if (cap == null) continue;

      final others = _expenses
          .where(
            (x) =>
                !x.fromSavings &&
                !isOriginal(x) &&
                inCycle(x) &&
                _matchesBudgetKey(x, key),
          )
          .fold(0.0, (sum, x) => sum + x.amount);
      final after = others + e.amount;

      var before = others;
      if (original != null &&
          !original.fromSavings &&
          inCycle(original) &&
          _matchesBudgetKey(original, key)) {
        before += original.amount;
      }

      if (after > cap && before <= cap) {
        hits.add(
          CategoryLimitHit(
            label: label,
            emoji: emoji,
            limit: cap,
            total: after,
          ),
        );
      }
    }
    return hits;
  }

  // ---------------------------------------------------------------------------
  // Recurring expenses
  // ---------------------------------------------------------------------------
  List<RecurringExpense> get recurringExpenses => _recurring;

  /// Why the last add/update of a recurring expense failed (for the UI).
  String? lastRecurringError;

  Future<void> fetchRecurring() async {
    try {
      _recurring = await DatabaseHelper.instance.getAllRecurring();
    } catch (e) {
      debugPrint('Could not load recurring expenses: $e');
    }
    notifyListeners();
  }

  /// Saves a new recurring expense and logs anything already due (a start
  /// date in the past is filled in right away). Returns how many expenses
  /// were logged, or null if it couldn't be saved.
  Future<int?> addRecurring(RecurringExpense r) async {
    try {
      final id = await DatabaseHelper.instance.insertRecurring(r);
      _recurring.add(r.copyWith(id: id));
    } catch (e) {
      // Same fallback as expenses: no database (e.g. Windows without the
      // desktop sqlite setup) -> keep it in memory for this session.
      debugPrint('Saving recurring expense in memory: $e');
      lastRecurringError = '$e';
      _recurring.add(r.copyWith(id: DateTime.now().millisecondsSinceEpoch));
    }
    notifyListeners();
    return generateDueRecurring();
  }

  /// Edits a recurring expense (matched by id). Returns how many expenses
  /// were logged as a result, or null if it couldn't be saved.
  Future<int?> updateRecurring(RecurringExpense r) async {
    if (r.id == null) return null;
    try {
      await DatabaseHelper.instance.updateRecurring(r);
    } catch (e) {
      debugPrint('Updating recurring expense in memory only: $e');
      lastRecurringError = '$e';
    }
    final i = _recurring.indexWhere((x) => x.id == r.id);
    if (i != -1) {
      _recurring[i] = r;
    } else {
      _recurring.add(r);
    }
    notifyListeners();
    return generateDueRecurring();
  }

  /// Pause or resume. Resuming does NOT back-fill the paused stretch: it
  /// picks up from the next occurrence.
  Future<void> setRecurringActive(RecurringExpense r, bool active) async {
    var updated = r.copyWith(active: active);
    if (active) {
      final skipped = r.dueOccurrences(DateTime.now());
      if (skipped.isNotEmpty) {
        updated = updated.copyWith(lastGenerated: skipped.last);
      }
    }
    await updateRecurring(updated);
  }

  /// Delete a recurring expense. Expenses it already logged stay in your
  /// history. Keep the object to hand it to [restoreRecurring] for undo.
  Future<void> deleteRecurring(RecurringExpense r) async {
    _recurring.removeWhere((x) => x.id == r.id);
    notifyListeners();
    if (r.id != null) {
      try {
        await DatabaseHelper.instance.deleteRecurring(r.id!);
      } catch (e) {
        debugPrint('Could not delete recurring expense: $e');
      }
    }
  }

  Future<void> restoreRecurring(RecurringExpense r) async {
    if (_recurring.any((x) => x.id == r.id)) return;
    try {
      await DatabaseHelper.instance.insertRecurring(r);
      _recurring.add(r);
      _recurring.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    } catch (e) {
      debugPrint('Could not restore recurring expense: $e');
    }
    notifyListeners();
  }

  /// Logs every occurrence that is due (on or before today) and hasn't been
  /// logged yet, dated on the day it was due, so a week of not opening the
  /// app still leaves an accurate history. Safe to call repeatedly. Returns
  /// how many expenses were created.
  Future<int> generateDueRecurring() async {
    if (_generatingRecurring) return 0;
    _generatingRecurring = true;
    var created = 0;
    try {
      final now = DateTime.now();
      for (final r in List<RecurringExpense>.of(_recurring)) {
        final rid = r.id;
        if (!r.active || rid == null) continue;

        final due = r.dueOccurrences(now);
        if (due.isEmpty) continue;

        for (final day in due) {
          // Belt and braces: never log the same rule twice for one day.
          final already = _expenses.any(
            (x) => x.recurringId == rid && DateUtils.isSameDay(x.date, day),
          );
          if (already) continue;

          final expense = Expense(
            title: r.title,
            amount: r.amount,
            category: r.category,
            date: day,
            paymentMethod: r.paymentMethod,
            recurringId: rid,
          );
          try {
            final id = await DatabaseHelper.instance.insertExpense(expense);
            _expenses.add(expense.copyWith(id: id));
          } catch (e) {
            debugPrint('Saving recurring expense in memory: $e');
            _expenses.add(expense);
          }
          created++;
        }

        final updated = r.copyWith(lastGenerated: due.last);
        final i = _recurring.indexWhere((x) => x.id == rid);
        if (i != -1) _recurring[i] = updated;
        try {
          await DatabaseHelper.instance.updateRecurring(updated);
        } catch (e) {
          debugPrint('Could not update recurring progress: $e');
        }
      }
    } finally {
      _generatingRecurring = false;
    }

    if (created > 0) {
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
      _syncReminder();
    }
    return created;
  }

  // ---------------------------------------------------------------------------
  // End-of-period summary notification
  // ---------------------------------------------------------------------------
  bool get cycleSummaryEnabled => _cycleSummaryEnabled;

  /// Returns false when the person refused the notification permission (the
  /// summary stays off).
  Future<bool> setCycleSummaryEnabled(bool enabled) async {
    var allowed = true;
    if (enabled) allowed = await ReminderService.instance.requestPermission();
    _cycleSummaryEnabled = enabled && allowed;
    notifyListeners();
    _saveSettings();
    return allowed;
  }

  String _cycleLabel(SavingsCycle c) {
    if (_cycleType == AllowanceCycleType.monthly) {
      return DateFormat('MMMM yyyy').format(c.start);
    }
    return '${DateFormat('MMM d').format(c.start)} – ${DateFormat('MMM d').format(c.end)}';
  }

  /// Notices when a budget period has finished since the last time we told
  /// the person, and sends one summary notification for it. Runs at launch
  /// and when the app returns to the foreground.
  Future<void> _checkCycleRollover() async {
    final now = DateTime.now();
    final thisStart = currentCycleStart(now);
    final prevDay = DateTime(
      thisStart.year,
      thisStart.month,
      thisStart.day - 1,
    );
    final prevStart = currentCycleStart(prevDay);
    final marker = DateFormat('yyyy-MM-dd').format(prevStart);
    if (_lastSummaryCycle == marker) return;

    SavingsCycle? finished;
    for (final c in savingsHistory()) {
      if (DateUtils.isSameDay(c.start, prevStart)) finished = c;
    }

    // Remember it either way so we never announce the same period twice
    // (and never announce periods from before tracking began).
    _lastSummaryCycle = marker;
    _saveSettings();
    if (finished == null || !_cycleSummaryEnabled) return;

    final label = _cycleLabel(finished);
    final String title;
    final String body;
    if (finished.leftover > 0) {
      title = 'Period complete 🎉';
      body =
          '$label ended: you saved ${formatPeso(finished.leftover, decimals: 0)}. '
          "It's now in your savings.";
    } else if (finished.leftover < 0) {
      title = 'Period complete';
      body =
          '$label ended ${formatPeso(finished.leftover.abs(), decimals: 0)} over budget. '
          'The shortfall carries into this period.';
    } else {
      title = 'Period complete';
      body = '$label ended right on budget.';
    }

    // First summary is a natural moment to ask for notification permission.
    await ReminderService.instance.requestPermission();
    await ReminderService.instance.showCycleSummary(title: title, body: body);
  }

  // ---------------------------------------------------------------------------
  // Calendar helpers
  // ---------------------------------------------------------------------------
  /// day-of-month -> total spent that day (only days that have spending).
  /// Pass [type] to total only that major type (for the calendar's type
  /// filter chips).
  Map<int, double> getDailyTotalsForMonth(DateTime month, {ExpenseType? type}) {
    final totals = <int, double>{};
    for (final e in _expenses) {
      if (e.date.year == month.year && e.date.month == month.month) {
        if (e.fromSavings) continue;
        if (type != null && e.type != type.name) continue;
        totals[e.date.day] = (totals[e.date.day] ?? 0) + e.amount;
      }
    }
    return totals;
  }

  /// Expenses on a given day, newest first.
  List<Expense> getExpensesOn(DateTime day) {
    final list = _expenses
        .where((e) => DateUtils.isSameDay(e.date, day))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Type name ('Food' / 'Transportation' / 'Other') -> total spent that day.
  Map<String, double> typeTotalsForDay(DateTime day) {
    final totals = <String, double>{};
    for (final e in getExpensesOn(day)) {
      if (e.fromSavings) continue;
      totals[e.type] = (totals[e.type] ?? 0) + e.amount;
    }
    return totals;
  }

  /// Type name -> total spent that month.
  Map<String, double> typeTotalsForMonth(DateTime month) {
    final totals = <String, double>{};
    for (final e in _expenses) {
      if (e.date.year == month.year && e.date.month == month.month) {
        if (e.fromSavings) continue;
        totals[e.type] = (totals[e.type] ?? 0) + e.amount;
      }
    }
    return totals;
  }

  /// The earliest date you've logged anything, or null if you haven't
  /// logged anything yet. Used so streaks/no-spend days don't count days
  /// before you started using the app.
  DateTime? get firstExpenseDate {
    if (_expenses.isEmpty) return null;
    final earliest = _expenses
        .map((e) => e.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(earliest.year, earliest.month, earliest.day);
  }

  /// True if [day] has zero spending, is on or before today, and is on or
  /// after your first logged expense (so it counts as a deliberate
  /// no-spend day, not just an unused day).
  bool isNoSpendDay(DateTime day) {
    final first = firstExpenseDate;
    if (first == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (d.isAfter(todayOnly) || d.isBefore(first)) return false;
    return totalSpentOn(d) == 0;
  }

  /// How many days in a row, ending today, you've stayed at or under your
  /// daily limit (a no-spend day counts). Stops at your first logged
  /// expense so it never counts days before you started tracking.
  int get currentUnderLimitStreak {
    final first = firstExpenseDate;
    if (first == null) return 0;
    var day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    var streak = 0;
    while (!day.isBefore(first)) {
      if (totalSpentOn(day) > dailyLimitFor(day)) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The weekday (1 = Monday .. 7 = Sunday) with the highest average
  /// spend, and that average — computed over every day from your first
  /// logged expense through today. Null if you have no expenses yet.
  MapEntry<int, double>? get busiestWeekday {
    final first = firstExpenseDate;
    if (first == null) return null;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);

    final totalsByWeekday = <int, double>{};
    final daysByWeekday = <int, int>{};
    for (var d = first; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      totalsByWeekday[d.weekday] =
          (totalsByWeekday[d.weekday] ?? 0) + totalSpentOn(d);
      daysByWeekday[d.weekday] = (daysByWeekday[d.weekday] ?? 0) + 1;
    }

    MapEntry<int, double>? best;
    totalsByWeekday.forEach((weekday, total) {
      final avg = total / (daysByWeekday[weekday] ?? 1);
      if (best == null || avg > best!.value) best = MapEntry(weekday, avg);
    });
    return best;
  }

  // ---------------------------------------------------------------------------
  // End-of-day reminder
  // ---------------------------------------------------------------------------
  bool get reminderEnabled => _reminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;

  /// True when at least one expense is logged for today.
  bool get hasLoggedExpenseToday {
    final now = DateTime.now();
    return _expenses.any((e) => DateUtils.isSameDay(e.date, now));
  }

  /// Turn the reminder on/off and/or change its time. Returns false when the
  /// person refused the notification permission (the reminder stays off).
  Future<bool> setReminder({required bool enabled, TimeOfDay? time}) async {
    var allowed = true;
    if (enabled) {
      allowed = await ReminderService.instance.requestPermission();
    }
    _reminderEnabled = enabled && allowed;
    if (time != null) _reminderTime = time;
    notifyListeners();
    _saveSettings();
    await _syncReminder();
    return allowed;
  }

  Future<void> _syncReminder() {
    return ReminderService.instance.sync(
      enabled: _reminderEnabled,
      time: _reminderTime,
      loggedToday: hasLoggedExpenseToday,
    );
  }

  // ---------------------------------------------------------------------------
  // Saved settings (budgets, custom daily limit, Quick Add shortcuts)
  // ---------------------------------------------------------------------------
  static const _prefsKey = 'expense_settings_v1';

  /// Call once at launch: settings first (so the daily limit is right), then expenses.
  Future<void> init() async {
    await _loadSettings();
    notifyListeners();
    await fetchExpenses();
    await fetchIncome();
    await fetchRecurring();
    final created = await generateDueRecurring();
    // The "opened already over the limit" banner was decided before the
    // recurring expenses were logged, so decide again if any were added.
    if (created > 0 && !_launchBannerDismissed) {
      _launchBannerArmed = isOverDailyLimitToday;
      notifyListeners();
    }
    await _checkCycleRollover();
    _syncReminder();
  }

  /// Call when the app returns to the foreground: a phone left open overnight
  /// should still log today's recurring expenses and notice a new period.
  Future<void> onAppResumed() async {
    if (!_initialLoadDone) return;
    await generateDueRecurring();
    await _checkCycleRollover();
    _syncReminder();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return; // nothing saved yet -> keep the defaults
      _applySettings(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Could not load settings: $e');
    }
  }

  /// Overwrites the in-memory settings from [data] — same keys as
  /// [exportSettings] — then persists them. Loading at launch and restoring a
  /// backup both go through here, so a restored budget behaves exactly like a
  /// saved one. Returns false if [data] was too broken to apply; the previous
  /// settings are left alone in that case.
  bool applyImportedSettings(Map<String, dynamic> data) {
    try {
      _applySettings(data);
      notifyListeners();
      _saveSettings();
      return true;
    } catch (e) {
      debugPrint('Could not apply imported settings: $e');
      return false;
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    final budgets = (data['budgets'] as Map<String, dynamic>?) ?? {};
    _cycleBudgets
      ..clear()
      ..addAll(budgets.map((k, v) => MapEntry(k, (v as num).toDouble())));

    _customDailyLimit = (data['dailyLimit'] as num?)?.toDouble();

    final cycleTypeStr = data['cycleType'] as String?;
    if (cycleTypeStr != null) {
      _cycleType = AllowanceCycleType.values.firstWhere(
        (t) => t.name == cycleTypeStr,
        orElse: () => AllowanceCycleType.monthly,
      );
    }
    final anchorStr = data['cycleAnchor'] as String?;
    if (anchorStr != null) {
      _cycleAnchor = DateTime.parse(anchorStr);
    }
    final freshStr = data['carryoverFreshFrom'] as String?;
    _carryoverFreshFrom = freshStr != null ? DateTime.tryParse(freshStr) : null;

    final catBudgets = (data['categoryBudgets'] as Map<String, dynamic>?) ?? {};
    _categoryBudgets
      ..clear()
      ..addAll(catBudgets.map((k, v) => MapEntry(k, (v as num).toDouble())));
    _lastSummaryCycle = data['lastSummaryCycle'] as String?;
    _cycleSummaryEnabled = data['cycleSummaryEnabled'] as bool? ?? true;

    _reminderEnabled = data['reminderEnabled'] as bool? ?? false;
    final reminderMinutes = data['reminderMinutes'] as int?;
    if (reminderMinutes != null) {
      _reminderTime = TimeOfDay(
        hour: reminderMinutes ~/ 60,
        minute: reminderMinutes % 60,
      );
    }

    final items = data['quickAdd'] as List<dynamic>?;
    if (items != null) {
      _quickAddItems
        ..clear()
        ..addAll(
          items.map((e) => QuickAddItem.fromJson(e as Map<String, dynamic>)),
        );
    }
  }

  /// Everything this app keeps in preferences, in the shape a backup stores it.
  /// Doubles as the payload for [_saveSettings], so the two can't drift apart.
  Map<String, dynamic> exportSettings() {
    return {
      'budgets': Map<String, double>.from(_cycleBudgets),
      'dailyLimit': _customDailyLimit,
      'quickAdd': _quickAddItems.map((e) => e.toJson()).toList(),
      'cycleType': _cycleType.name,
      'cycleAnchor': _cycleAnchor.toIso8601String(),
      'carryoverFreshFrom': _carryoverFreshFrom?.toIso8601String(),
      'categoryBudgets': Map<String, double>.from(_categoryBudgets),
      'lastSummaryCycle': _lastSummaryCycle,
      'cycleSummaryEnabled': _cycleSummaryEnabled,
      'reminderEnabled': _reminderEnabled,
      'reminderMinutes': _reminderTime.hour * 60 + _reminderTime.minute,
    };
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(exportSettings()));
    } catch (e) {
      debugPrint('Could not save settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Backup / restore (Phase 5)
  // ---------------------------------------------------------------------------

  /// Merges a backup into what's already here and reports what it did.
  ///
  /// Nothing currently in the app is deleted or overwritten. Rows are matched
  /// on content rather than id (an id only means anything in the database that
  /// produced it), so importing the same file twice adds nothing the second
  /// time, and a backup that overlaps this device's data only fills the gaps.
  ///
  /// Settings (budgets, cycle, limits, quick add) are only replaced when
  /// [includeSettings] is set, since those are the one thing an import would
  /// otherwise silently overwrite.
  ///
  /// Doesn't log anything the recurring rules owed by today: the next launch
  /// or resume picks that up, and doing it here would risk double-logging
  /// occurrences that the file and this device both already have.
  Future<BackupImportSummary> importBackup(
    BackupFile backup, {
    bool includeSettings = false,
  }) async {
    final expenseKeys = {for (final e in _expenses) _expenseKey(e)};
    final incomeKeys = {for (final i in _income) _incomeKey(i)};
    final recurringIdsByKey = <String, int?>{
      for (final r in _recurring) _recurringKey(r): r.id,
    };

    var expensesAdded = 0;
    var expensesSkipped = 0;
    var incomeAdded = 0;
    var incomeSkipped = 0;
    var recurringAdded = 0;
    var recurringSkipped = 0;

    // The file's recurring id -> the id this database just handed out, so the
    // expenses that came with the file stay linked to their rule. Left
    // unresolved, they'd look hand-entered and the rule would log them again.
    final recurringIdMap = <int, int>{};

    for (final incoming in backup.recurring) {
      final rule = incoming.rule;
      final key = _recurringKey(rule);
      if (recurringIdsByKey.containsKey(key)) {
        // Already have this rule. Still remember which one, so the file's
        // expenses point at the rule we actually hold.
        final existingId = recurringIdsByKey[key];
        if (incoming.backupId != null && existingId != null) {
          recurringIdMap[incoming.backupId!] = existingId;
        }
        recurringSkipped++;
        continue;
      }

      int newId;
      try {
        newId = await DatabaseHelper.instance.insertRecurring(rule);
      } catch (e) {
        debugPrint('Saving imported recurring expense in memory: $e');
        newId = DateTime.now().millisecondsSinceEpoch;
      }
      _recurring.add(rule.copyWith(id: newId));
      recurringIdsByKey[key] = newId;
      recurringAdded++;
      if (incoming.backupId != null) recurringIdMap[incoming.backupId!] = newId;
    }

    for (final e in backup.expenses) {
      if (!expenseKeys.add(_expenseKey(e))) {
        expensesSkipped++;
        continue;
      }
      final oldRecurringId = e.recurringId;
      final row = oldRecurringId == null
          ? e
          : e.copyWith(recurringId: recurringIdMap[oldRecurringId]);
      try {
        final id = await DatabaseHelper.instance.insertExpense(row);
        _expenses.add(row.copyWith(id: id));
      } catch (e) {
        debugPrint('Saving imported expense in memory: $e');
        _expenses.add(row);
      }
      expensesAdded++;
    }
    _expenses.sort((a, b) => b.date.compareTo(a.date));

    for (final i in backup.income) {
      if (!incomeKeys.add(_incomeKey(i))) {
        incomeSkipped++;
        continue;
      }
      try {
        final id = await DatabaseHelper.instance.insertIncome(i);
        _income.add(i.copyWith(id: id));
      } catch (e) {
        debugPrint('Saving imported income in memory: $e');
        _income.add(i);
      }
      incomeAdded++;
    }
    _income.sort((a, b) => b.date.compareTo(a.date));

    var settingsApplied = false;
    if (includeSettings && backup.hasSettings) {
      settingsApplied = applyImportedSettings(backup.settings);
    }

    notifyListeners();
    _syncReminder();

    return BackupImportSummary(
      expensesAdded: expensesAdded,
      expensesSkipped: expensesSkipped,
      incomeAdded: incomeAdded,
      incomeSkipped: incomeSkipped,
      recurringAdded: recurringAdded,
      recurringSkipped: recurringSkipped,
      settingsApplied: settingsApplied,
    );
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// What makes an expense "the same one" across two devices: same day, same
  /// amount, same what-it-was-for. Amount is rounded to two decimals so a
  /// float that made the round trip through JSON still matches.
  String _expenseKey(Expense e) =>
      '${_dayKey(e.date)}|${e.amount.toStringAsFixed(2)}|${e.title}|${e.category}';

  String _incomeKey(Income i) =>
      '${_dayKey(i.date)}|${i.amount.toStringAsFixed(2)}|${i.note}';

  String _recurringKey(RecurringExpense r) =>
      '${r.title}|${r.amount.toStringAsFixed(2)}|${r.frequency.name}|${_dayKey(r.startDate)}';

  // Load all expenses
  Future<void> fetchExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = await DatabaseHelper.instance.getAllExpenses();
    } catch (e) {
      debugPrint('SQFlite web/desktop fallback active: $e');
    } finally {
      _isLoading = false;
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        _launchBannerArmed = isOverDailyLimitToday;
      }
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Income (allowance / money-in)
  // ---------------------------------------------------------------------------
  List<Income> get income => _income;

  Future<void> fetchIncome() async {
    try {
      _income = await DatabaseHelper.instance.getAllIncome();
    } catch (e) {
      debugPrint('Could not load income: $e');
    }
    notifyListeners();
  }

  Future<void> addIncome(Income income) async {
    _income.insert(0, income);
    _income.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    try {
      final id = await DatabaseHelper.instance.insertIncome(income);
      final i = _income.indexOf(income);
      if (i != -1) _income[i] = income.copyWith(id: id);
      notifyListeners();
    } catch (e) {
      debugPrint('Could not save income to database: $e');
    }
  }

  int _incomeIndexOf(Income i) {
    if (i.id != null) return _income.indexWhere((x) => x.id == i.id);
    return _income.indexWhere((x) => identical(x, i));
  }

  /// Delete an income entry. Keep the [Income] you pass in so you can hand
  /// it to [restoreIncome] for an undo action.
  Future<void> deleteIncome(Income income) async {
    final i = _incomeIndexOf(income);
    if (i != -1) _income.removeAt(i);
    notifyListeners();

    if (income.id != null) {
      try {
        await DatabaseHelper.instance.deleteIncome(income.id!);
      } catch (e) {
        debugPrint('Could not delete income from database: $e');
      }
    }
  }

  /// Edit an income entry (in-memory update first, then persist — same
  /// pattern as [updateExpense]).
  Future<void> updateIncome(Income original, Income updated) async {
    final i = _incomeIndexOf(original);
    if (i != -1) {
      _income[i] = updated;
    } else {
      _income.insert(0, updated);
    }
    _income.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    if (updated.id != null) {
      try {
        await DatabaseHelper.instance.updateIncome(updated);
      } catch (e) {
        debugPrint('Could not update income in database: $e');
      }
    }
  }

  Future<void> restoreIncome(Income income) async {
    if (_incomeIndexOf(income) != -1) return;
    _income.add(income);
    _income.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    if (income.id != null) {
      try {
        await DatabaseHelper.instance.insertIncome(income);
      } catch (e) {
        debugPrint('Could not restore income in database: $e');
      }
    }
  }

  /// Income received on a given day, newest first.
  List<Income> getIncomeOn(DateTime day) {
    final list = _income
        .where((i) => DateUtils.isSameDay(i.date, day))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// day-of-month -> total income received that day (only days with income).
  Map<int, double> getIncomeTotalsForMonth(DateTime month) {
    final totals = <int, double>{};
    for (final i in _income) {
      if (i.date.year == month.year && i.date.month == month.month) {
        totals[i.date.day] = (totals[i.date.day] ?? 0) + i.amount;
      }
    }
    return totals;
  }

  double totalIncomeForMonth(DateTime month) {
    return _income
        .where((i) => i.date.year == month.year && i.date.month == month.month)
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  /// Your running balance at the end of [day]: all income received on or
  /// before that day, minus all expenses logged on or before that day.
  /// This is deliberately not scoped to a calendar month, since an
  /// irregular allowance doesn't reset on the 1st.
  double runningBalanceThrough(DateTime day) {
    final cutoff = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final incomeTotal = _income
        .where((i) => !i.date.isAfter(cutoff))
        .fold(0.0, (sum, i) => sum + i.amount);
    final expenseTotal = _expenses
        .where((e) => !e.date.isAfter(cutoff))
        .fold(0.0, (sum, e) => sum + e.amount);
    return incomeTotal - expenseTotal;
  }

  double get currentBalance => runningBalanceThrough(DateTime.now());

  /// Average amount spent per day over the last [days] days (today
  /// included), used to project the runway below. Only looks at days from
  /// your first logged expense onward, so a brand-new account isn't
  /// skewed by empty history.
  double averageDailySpend({int days = 14}) {
    final first = firstExpenseDate;
    if (first == null) return 0;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(Duration(days: days - 1));
    final windowStart = start.isBefore(first) ? first : start;
    final windowDays = end.difference(windowStart).inDays + 1;
    if (windowDays <= 0) return 0;

    var total = 0.0;
    for (
      var d = windowStart;
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      total += totalSpentOn(d);
    }
    return total / windowDays;
  }

  /// The date your current balance is projected to hit zero, based on your
  /// recent average daily spend. Null if you're not spending (so there's
  /// nothing to project) or you haven't logged anything yet.
  DateTime? get projectedRunwayDate {
    final avg = averageDailySpend();
    if (avg <= 0) return null;
    final balance = currentBalance;
    if (balance <= 0) return DateTime.now();
    final daysLeft = (balance / avg).floor();
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: daysLeft));
  }

  // Add a new expense. Returns a LimitCheck so the UI can show the
  // "daily limit exceeded" pop-up when this expense pushes the day over.
  Future<LimitCheck> addExpense(Expense expense) async {
    final limit = dailyLimitFor(expense.date);
    final before = totalSpentOn(expense.date);
    final hits = _categoryHits(expense);

    try {
      final id = await DatabaseHelper.instance.insertExpense(expense);
      _expenses.insert(0, expense.copyWith(id: id));
    } catch (e) {
      debugPrint('Saving locally in memory: $e');
      _expenses.insert(0, expense);
    }
    notifyListeners();
    _syncReminder();

    return LimitCheck(
      day: expense.date,
      limit: limit,
      // Paid-from-savings expenses never count toward the day's limit.
      dayTotal: before + (expense.fromSavings ? 0.0 : expense.amount),
      wasOver: before > limit,
      categoryHits: hits,
    );
  }

  // Index of an expense in the list: by id when it has one, otherwise by
  // identity (expenses saved only in memory have no id).
  int _indexOf(Expense e) {
    if (e.id != null) return _expenses.indexWhere((x) => x.id == e.id);
    return _expenses.indexWhere((x) => identical(x, e));
  }

  /// Edit an expense. Returns a LimitCheck (like addExpense) so the UI can
  /// show the "daily limit exceeded" pop-up if the edit pushed the day over.
  Future<LimitCheck> updateExpense(Expense original, Expense updated) async {
    // Editing an auto-logged expense keeps its link to the recurring entry.
    if (updated.recurringId == null && original.recurringId != null) {
      updated = updated.copyWith(recurringId: original.recurringId);
    }
    final limit = dailyLimitFor(updated.date);
    final hits = _categoryHits(updated, original: original);
    final i = _indexOf(original);

    // Everything else logged on the (new) day, without the original.
    final others = _expenses
        .where(
          (e) =>
              !identical(e, original) &&
              !(original.id != null && e.id == original.id) &&
              !e.fromSavings &&
              DateUtils.isSameDay(e.date, updated.date),
        )
        .fold(0.0, (sum, e) => sum + e.amount);

    final sameDay = DateUtils.isSameDay(original.date, updated.date);
    final totalBefore =
        others + (sameDay && !original.fromSavings ? original.amount : 0.0);

    if (i != -1) {
      _expenses[i] = updated;
    } else {
      _expenses.insert(0, updated);
    }
    notifyListeners();
    _syncReminder();

    if (updated.id != null) {
      try {
        await DatabaseHelper.instance.updateExpense(updated);
      } catch (e) {
        debugPrint('Could not update expense in database: $e');
      }
    }

    return LimitCheck(
      day: updated.date,
      limit: limit,
      dayTotal: others + (updated.fromSavings ? 0.0 : updated.amount),
      wasOver: totalBefore > limit,
      categoryHits: hits,
    );
  }

  /// Delete an expense. The list updates immediately (no full reload), which
  /// is what lets a swipe-to-dismiss row leave the tree cleanly.
  /// Keep the [Expense] you pass in so you can hand it to [restoreExpense].
  Future<void> deleteExpense(Expense expense) async {
    final i = _indexOf(expense);
    if (i != -1) _expenses.removeAt(i);
    notifyListeners();
    _syncReminder();

    if (expense.id != null) {
      try {
        await DatabaseHelper.instance.deleteExpense(expense.id!);
      } catch (e) {
        debugPrint('Could not delete expense from database: $e');
      }
    }
  }

  /// Undo a delete: puts the expense back (with its original id).
  Future<void> restoreExpense(Expense expense) async {
    if (_indexOf(expense) != -1) return;
    _expenses.add(expense);
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    _syncReminder();

    if (expense.id != null) {
      try {
        await DatabaseHelper.instance.insertExpense(expense);
      } catch (e) {
        debugPrint('Could not restore expense in database: $e');
      }
    }
  }

  // Quick Add Management Methods
  void addQuickAddItem(
    String title,
    double amount,
    String emoji,
    String category,
  ) {
    _quickAddItems.add(
      QuickAddItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        emoji: emoji,
        category: category,
      ),
    );
    notifyListeners();
    _saveSettings();
  }

  void removeQuickAddItem(String id) {
    _quickAddItems.removeWhere((item) => item.id == id);
    notifyListeners();
    _saveSettings();
  }

  // Filter expenses by selected index (0: This Week, 1: This Month, 2: Last Month)
  List<Expense> getFilteredExpenses(int filterIndex) {
    final now = DateTime.now();

    return _expenses.where((expense) {
      if (filterIndex == 0) {
        // THIS WEEK
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return expense.date.isAfter(
              startOfWeek.subtract(const Duration(seconds: 1)),
            ) &&
            expense.date.isBefore(endOfWeek);
      } else if (filterIndex == 1) {
        // THIS MONTH
        return expense.date.year == now.year && expense.date.month == now.month;
      } else {
        // LAST MONTH
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        return expense.date.year == lastMonthDate.year &&
            expense.date.month == lastMonthDate.month;
      }
    }).toList();
  }

  // Total spending for active period
  double getTotalSpending(int filterIndex) {
    final filtered = getFilteredExpenses(filterIndex);
    return filtered.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Daily average calculation
  double getDailyAverage(int filterIndex) {
    final filtered = getFilteredExpenses(filterIndex);
    if (filtered.isEmpty) return 0.0;

    final uniqueDays = filtered
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;
    return uniqueDays == 0 ? 0.0 : getTotalSpending(filterIndex) / uniqueDays;
  }

  // Breakdown by subcategory (Lunch, Jeepney, ...)
  List<Map<String, dynamic>> getCategoryBreakdown(int filterIndex) {
    final filtered = getFilteredExpenses(filterIndex);
    final totals = <String, double>{};
    for (final item in filtered) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }
    return _buildBreakdown(
      totals,
      getTotalSpending(filterIndex),
      (name) => CategoryData.colorFor(name),
    );
  }

  // Breakdown by major type (Food / Transportation / Other)
  List<Map<String, dynamic>> getTypeBreakdown(int filterIndex) {
    final filtered = getFilteredExpenses(filterIndex);
    final totals = <String, double>{};
    for (final item in filtered) {
      totals[item.type] = (totals[item.type] ?? 0) + item.amount;
    }
    return _buildBreakdown(
      totals,
      getTotalSpending(filterIndex),
      (name) => CategoryData.typeByName(name).color,
    );
  }

  List<Map<String, dynamic>> _buildBreakdown(
    Map<String, double> totals,
    double total,
    Color Function(String name) colorFor,
  ) {
    if (total == 0) return [];

    final breakdown = totals.entries.map((entry) {
      final pct = ((entry.value / total) * 100).round();
      return {
        'name': entry.key,
        'amt': entry.value,
        'pct': '$pct%',
        'color': colorFor(entry.key),
      };
    }).toList();

    breakdown.sort(
      (a, b) => (b['amt'] as double).compareTo(a['amt'] as double),
    );
    return breakdown;
  }

  // Bar chart data generator requested by StatsScreen
  List<double> getBarChartData(int filterIndex) {
    final now = DateTime.now();

    if (filterIndex == 0) {
      // Past 7 Days (This Week)
      return List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        return _expenses
            .where(
              (e) =>
                  e.date.year == day.year &&
                  e.date.month == day.month &&
                  e.date.day == day.day,
            )
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    } else if (filterIndex == 1) {
      // 4 Weeks of This Month
      return List.generate(4, (i) {
        final startDay = i * 7 + 1;
        final endDay = (i + 1) * 7;
        return _expenses
            .where(
              (e) =>
                  e.date.year == now.year &&
                  e.date.month == now.month &&
                  e.date.day >= startDay &&
                  e.date.day <= endDay,
            )
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    } else {
      // 4 Weeks of Last Month
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return List.generate(4, (i) {
        final startDay = i * 7 + 1;
        final endDay = (i + 1) * 7;
        return _expenses
            .where(
              (e) =>
                  e.date.year == lastMonth.year &&
                  e.date.month == lastMonth.month &&
                  e.date.day >= startDay &&
                  e.date.day <= endDay,
            )
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    }
  }

  // Period label generator requested by StatsScreen
  String getPeriodLabel(int filterIndex) {
    final now = DateTime.now();
    final monthNames = [
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

    if (filterIndex == 0) {
      return 'This Week';
    } else if (filterIndex == 1) {
      return '${monthNames[now.month - 1]} ${now.year}';
    } else {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return '${monthNames[lastMonth.month - 1]} ${lastMonth.year}';
    }
  }

  // Legacy compatibility helper
  List<double> getPast7DaysTotals() => getBarChartData(0);
}
