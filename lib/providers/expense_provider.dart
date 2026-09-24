import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

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
}

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];

  // Per-month budgets, keyed 'yyyy-MM'. Falls back to _defaultBudget
  // for any month that hasn't had a budget explicitly set.
  final Map<String, double> _monthlyBudgets = {};
  static const double _defaultBudget = 6000.0;
  bool _isLoading = false;

  String _monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);

  // Initial Quick Add Items State
  final List<QuickAddItem> _quickAddItems = [
    QuickAddItem(id: '1', title: 'Siomai Rice', amount: 85.0, emoji: '🍜', category: 'Lunch'),
    QuickAddItem(id: '2', title: 'Egg & Rice', amount: 80.0, emoji: '🍳', category: 'Breakfast'),
    QuickAddItem(id: '3', title: 'Milk Tea', amount: 45.0, emoji: '🧋', category: 'Drinks'),
  ];

  // Getters
  List<Expense> get expenses => _expenses;
  double get monthlyBudget => getBudgetForMonth(DateTime.now());
  bool get isLoading => _isLoading;
  List<QuickAddItem> get quickAddItems => _quickAddItems;

  // Budget for a specific month; falls back to the default if unset
  double getBudgetForMonth(DateTime month) {
    return _monthlyBudgets[_monthKey(month)] ?? _defaultBudget;
  }

  // Set the budget for a specific month (defaults to the current month)
  void updateBudget(double newBudget, {DateTime? month}) {
    final key = _monthKey(month ?? DateTime.now());
    _monthlyBudgets[key] = newBudget;
    notifyListeners();
  }

  // Calculated Metrics (scoped to the current month)
  double totalSpentForMonth(DateTime month) {
    return _expenses
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalSpent => totalSpentForMonth(DateTime.now());

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
      notifyListeners();
    }
  }

  // Add a new expense
  Future<void> addExpense(Expense expense) async {
    try {
      final id = await DatabaseHelper.instance.insertExpense(expense);
      final savedExpense = Expense(
        id: id,
        title: expense.title,
        amount: expense.amount,
        category: expense.category,
        date: expense.date,
        paymentMethod: expense.paymentMethod,
      );
      _expenses.insert(0, savedExpense);
    } catch (e) {
      debugPrint('Saving locally in memory: $e');
      _expenses.insert(0, expense);
    }
    notifyListeners();
  }

  // Delete an expense
  Future<void> deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await fetchExpenses();
  }

  // Quick Add Management Methods
  void addQuickAddItem(String title, double amount, String emoji, String category) {
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
  }

  void removeQuickAddItem(String id) {
    _quickAddItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Filter expenses by selected index (0: This Week, 1: This Month, 2: Last Month)
  List<Expense> getFilteredExpenses(int filterIndex) {
    final now = DateTime.now();

    return _expenses.where((expense) {
      if (filterIndex == 0) {
        // THIS WEEK
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return expense.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
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

  // Category breakdown list
  List<Map<String, dynamic>> getCategoryBreakdown(int filterIndex) {
    final filtered = getFilteredExpenses(filterIndex);
    final total = getTotalSpending(filterIndex);
    if (total == 0) return [];

    final totalsByCategory = <String, double>{};
    for (final item in filtered) {
      totalsByCategory[item.category] =
          (totalsByCategory[item.category] ?? 0) + item.amount;
    }

    final categoryColors = {
      'Lunch': const Color(0xFF00C853),
      'Dinner': const Color(0xFF6C5CE7),
      'Breakfast': const Color(0xFFFFA000),
      'Drinks': const Color(0xFF00CEC9),
      'Snacks': const Color(0xFFFF7675),
      'Fast Food': const Color(0xFFF59E0B),
      'Coffee': const Color(0xFF8B5CF6),
      'Groceries': const Color(0xFF10B981),
      'Other': const Color(0xFF64748B),
    };

    final breakdown = totalsByCategory.entries.map((entry) {
      final pct = ((entry.value / total) * 100).round();
      return {
        'name': entry.key,
        'amt': entry.value,
        'pct': '$pct%',
        'color': categoryColors[entry.key] ?? Colors.grey,
      };
    }).toList();

    breakdown.sort((a, b) => (b['amt'] as double).compareTo(a['amt'] as double));
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
            .where((e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day)
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    } else if (filterIndex == 1) {
      // 4 Weeks of This Month
      return List.generate(4, (i) {
        final startDay = i * 7 + 1;
        final endDay = (i + 1) * 7;
        return _expenses
            .where((e) =>
                e.date.year == now.year &&
                e.date.month == now.month &&
                e.date.day >= startDay &&
                e.date.day <= endDay)
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    } else {
      // 4 Weeks of Last Month
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return List.generate(4, (i) {
        final startDay = i * 7 + 1;
        final endDay = (i + 1) * 7;
        return _expenses
            .where((e) =>
                e.date.year == lastMonth.year &&
                e.date.month == lastMonth.month &&
                e.date.day >= startDay &&
                e.date.day <= endDay)
            .fold(0.0, (sum, item) => sum + item.amount);
      });
    }
  }

  // Period label generator requested by StatsScreen
  String getPeriodLabel(int filterIndex) {
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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