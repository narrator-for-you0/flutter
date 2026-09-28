import 'expense_category.dart';

class Expense {
  final int? id;
  final String title;
  final double amount;
  final String category; // subcategory label, e.g. 'Lunch' or 'Jeepney'
  final DateTime date;
  final String paymentMethod;

  /// True when this was paid out of savings (unspent money from past
  /// periods). Such expenses don't count against the budget, the daily
  /// limit, or streaks, but they still reduce your real balance.
  final bool fromSavings;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.paymentMethod = 'Cash',
    this.fromSavings = false,
  });

  /// Major type ('Food' / 'Transportation' / 'Other'), derived from [category].
  String get type => CategoryData.typeOfCategory(category).name;

  // Convert Expense object into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'fromSavings': fromSavings ? 1 : 0,
    };
  }

  // Convert Map from SQLite into an Expense object
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
      fromSavings: (map['fromSavings'] as int? ?? 0) == 1,
    );
  }
}