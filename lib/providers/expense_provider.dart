import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

// Model for Customizable Quick Add Shortcuts
class QuickAddItem {
  final String id;
  final String title;
  final double amount;
  final String emoji;

  QuickAddItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.emoji,
  });
}

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  double _monthlyBudget = 6000.0; // Default budget limit
  bool _isLoading = false;

  // Initial Quick Add Items State
  List<QuickAddItem> _quickAddItems = [
    QuickAddItem(id: '1', title: 'Siomai Rice', amount: 85.0, emoji: '🍜'),
    QuickAddItem(id: '2', title: 'Egg & Rice', amount: 80.0, emoji: '🍳'),
    QuickAddItem(id: '3', title: 'Milk Tea', amount: 45.0, emoji: '🧋'),
  ];

  // Getters
  List<Expense> get expenses => _expenses;
  double get monthlyBudget => _monthlyBudget;
  bool get isLoading => _isLoading;
  List<QuickAddItem> get quickAddItems => _quickAddItems;

  // Calculated Metrics
  double get totalSpent {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get remainingBudget {
    final remaining = _monthlyBudget - totalSpent;
    return remaining < 0 ? 0 : remaining;
  }

  double get budgetPercentage {
    if (_monthlyBudget == 0) return 0.0;
    final pct = totalSpent / _monthlyBudget;
    return pct > 1.0 ? 1.0 : pct;
  }

  int get budgetPercentageInt {
    return (budgetPercentage * 100).toInt();
  }

  // Load all expenses
  Future<void> fetchExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _expenses = await DatabaseHelper.instance.getAllExpenses();
    } catch (e) {
      debugPrint("SQFlite web fallback active: $e");
      // Keeps local state responsive in browser memory if SQLite fails
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
      );
      _expenses.insert(0, savedExpense);
    } catch (e) {
      debugPrint("Saving locally in memory for Web: $e");
      _expenses.insert(0, expense); // Instant UI update fallback
    }
    notifyListeners();
  }

  // Delete an expense
  Future<void> deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await fetchExpenses(); // Refresh list & recalculate totals
  }

  // Update monthly budget limit
  void updateBudget(double newBudget) {
    _monthlyBudget = newBudget;
    notifyListeners();
  }

  // Quick Add Management Methods
  void addQuickAddItem(String title, double amount, String emoji) {
    _quickAddItems.add(
      QuickAddItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        emoji: emoji,
      ),
    );
    notifyListeners();
  }

  void removeQuickAddItem(String id) {
    _quickAddItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}