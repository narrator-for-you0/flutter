import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Theme Colors
  static const primaryGreen = Color(0xFF00C853);
  static const darkTextColor = Color(0xFF1E293B);
  static const labelColor = Color(0xFF64748B);
  static const lightBgColor = Color(0xFFF8FAFC);
  static const cardBorderColor = Color(0xFFF1F5F9);

  final List<Map<String, String>> _categories = [
    {'label': 'All', 'icon': ''},
    {'label': 'Breakfast', 'icon': '🍳'},
    {'label': 'Lunch', 'icon': '🍜'},
    {'label': 'Dinner', 'icon': '🍽️'},
    {'label': 'Drinks', 'icon': '🥤'},
  ];

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final allExpenses = expenseProvider.expenses;

    // Filter logic based on Search Query and Selected Category Filter
    final filteredExpenses = allExpenses.where((expense) {
      final matchesSearch = expense.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || expense.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Group expenses by Date
    final Map<String, List<Expense>> groupedExpenses = {};
    for (var expense in filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
    }

    final sortedDates = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Expense History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track, search, and manage all your past food purchases',
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: lightBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: labelColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: const InputDecoration(
                                hintText: 'Search expenses (e.g., Pizza, Coffee)',
                                hintStyle: TextStyle(color: labelColor, fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: lightBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.tune, color: labelColor, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['label'];

                  // Count items per category
                  final count = cat['label'] == 'All'
                      ? allExpenses.length
                      : allExpenses.where((e) => e.category == cat['label']).length;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat['label']!),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen : lightBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (cat['icon']!.isNotEmpty) ...[
                            Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            cat['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : darkTextColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($count)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white70 : labelColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Expense Cards Grouped by Date
            Expanded(
              child: sortedDates.isEmpty
                  ? const Center(
                      child: Text(
                        'No expenses found',
                        style: TextStyle(color: labelColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final dateStr = sortedDates[index];
                        final items = groupedExpenses[dateStr]!;
                        final totalDaily = items.fold(0.0, (sum, item) => sum + item.amount);

                        return _buildDateCardGroup(dateStr, items, totalDaily);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCardGroup(String dateStr, List<Expense> items, double totalDaily) {
    final DateTime parsedDate = DateTime.parse(dateStr);
    final isToday = DateUtils.isSameDay(parsedDate, DateTime.now());
    final isYesterday = DateUtils.isSameDay(parsedDate, DateTime.now().subtract(const Duration(days: 1)));

    String formattedHeader = DateFormat('MMMM d, yyyy').format(parsedDate);
    if (isToday) {
      formattedHeader = 'Today, $formattedHeader';
    } else if (isYesterday) {
      formattedHeader = 'Yesterday, $formattedHeader';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: lightBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        children: [
          // Header Row (Date & Item Count)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      formattedHeader,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: const TextStyle(fontSize: 12, color: labelColor),
                  ),
                ),
              ],
            ),
          ),

          // Items Container
          Container(
            color: Colors.white,
            child: Column(
              children: items.map((expense) => _buildExpenseRow(expense)).toList(),
            ),
          ),

          // Daily Total Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4), // Soft green tint
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                Text(
                  '₱${totalDaily.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    // Dynamic Icon & Colors based on Category
    String iconEmoji = '🍽️';
    Color iconBg = const Color(0xFFF1F5F9);

    if (expense.category == 'Drinks') {
      iconEmoji = '🥤';
      iconBg = const Color(0xFFE0F2FE);
    } else if (expense.category == 'Lunch') {
      iconEmoji = '🍜';
      iconBg = const Color(0xFFDCFCE7);
    } else if (expense.category == 'Breakfast') {
      iconEmoji = '🍳';
      iconBg = const Color(0xFFFEF3C7);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Emoji Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),

              // Title and Meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${expense.category}  •  ${DateFormat('hh:mm a').format(expense.date)}',
                          style: const TextStyle(fontSize: 12, color: labelColor),
                        ),
                        const SizedBox(width: 6),
                        // Payment Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: lightBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GCash', // Fallback or expense.paymentMethod
                            style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Text(
                '₱${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: cardBorderColor),
      ],
    );
  }
}