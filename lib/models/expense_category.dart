import 'package:flutter/material.dart';

/// A subcategory inside a major type (e.g. "Lunch" inside Food).
class SubCategory {
  final String label;
  final String emoji;
  final Color color;

  const SubCategory(this.label, this.emoji, this.color);
}

/// A major expense type (Food / Transportation / Other) and its subcategories.
class ExpenseType {
  final String name; // e.g. 'Food'
  final String emoji;
  final Color color; // strong accent
  final Color softColor; // light background tint
  final List<SubCategory> subCategories;

  const ExpenseType({
    required this.name,
    required this.emoji,
    required this.color,
    required this.softColor,
    required this.subCategories,
  });
}

/// Single source of truth for types + subcategories.
///
/// IMPORTANT: subcategory labels must be unique across ALL types. The
/// database only stores the subcategory label (`Expense.category`) and the
/// type is looked up from it, so old rows keep working without a migration.
class CategoryData {
  CategoryData._();

  static const food = ExpenseType(
    name: 'Food',
    emoji: '🍽️',
    color: Color(0xFF00C853),
    softColor: Color(0xFFDCFCE7),
    subCategories: [
      SubCategory('Breakfast', '🍳', Color(0xFFFFA000)),
      SubCategory('Lunch', '🍜', Color(0xFF00C853)),
      SubCategory('Dinner', '🍽️', Color(0xFF6C5CE7)),
      SubCategory('Snacks', '🍪', Color(0xFFFF7675)),
      SubCategory('Drinks', '🥤', Color(0xFF00CEC9)),
      SubCategory('Fast Food', '🍔', Color(0xFFF59E0B)),
      SubCategory('Coffee', '☕', Color(0xFF8B5CF6)),
      SubCategory('Groceries', '🛒', Color(0xFF10B981)),
      SubCategory('Other', '🍴', Color(0xFF64748B)),
    ],
  );

  static const transportation = ExpenseType(
    name: 'Transportation',
    emoji: '🚌',
    color: Color(0xFF3B82F6),
    softColor: Color(0xFFDBEAFE),
    subCategories: [
      SubCategory('Jeepney', '🚐', Color(0xFF3B82F6)),
      SubCategory('Tricycle', '🛺', Color(0xFF0EA5E9)),
      SubCategory('Bus', '🚌', Color(0xFF6366F1)),
      SubCategory('Habal-habal', '🏍️', Color(0xFF14B8A6)),
      SubCategory('Grab / Taxi', '🚕', Color(0xFF22C55E)),
      SubCategory('Fuel', '⛽', Color(0xFFEF4444)),
      SubCategory('Parking', '🅿️', Color(0xFF64748B)),
    ],
  );

  static const other = ExpenseType(
    name: 'Other',
    emoji: '🧾',
    color: Color(0xFFF97316),
    softColor: Color(0xFFFFEDD5),
    subCategories: [
      SubCategory('Supplies', '📚', Color(0xFFF97316)),
      SubCategory('Printing', '🖨️', Color(0xFF8B5CF6)),
      SubCategory('Load / Data', '📱', Color(0xFF06B6D4)),
      SubCategory('Leisure', '🎮', Color(0xFFEC4899)),
      SubCategory('Health', '💊', Color(0xFFEF4444)),
      SubCategory('Misc', '🧾', Color(0xFF64748B)),
    ],
  );

  static const List<ExpenseType> types = [food, transportation, other];

  /// Type by name. Falls back to Food (every pre-existing expense is food).
  static ExpenseType typeByName(String? name) {
    return types.firstWhere((t) => t.name == name, orElse: () => food);
  }

  /// The type that owns a subcategory label. Unknown labels count as Food.
  static ExpenseType typeOfCategory(String category) {
    for (final t in types) {
      if (t.subCategories.any((s) => s.label == category)) return t;
    }
    return food;
  }

  static SubCategory? findSubCategory(String category) {
    for (final t in types) {
      for (final s in t.subCategories) {
        if (s.label == category) return s;
      }
    }
    return null;
  }

  static String emojiFor(String category) =>
      findSubCategory(category)?.emoji ?? typeOfCategory(category).emoji;

  static Color colorFor(String category) =>
      findSubCategory(category)?.color ?? Colors.grey;
}
