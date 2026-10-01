import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../themes/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedCategory = 'All';

  // Theme Colors
  static const primaryGreen = Color(0xFF00C853);
  static Color get darkTextColor => AppColors.text;
  static Color get labelColor => AppColors.muted;
  static Color get lightBgColor => AppColors.card;
  static Color get cardBorderColor => AppColors.border;

  // Type-chip label for money coming in (not a real expense type)
  static const _incomeChip = 'Income';

  DateTime _entryDate(Object entry) =>
      entry is Expense ? entry.date : (entry as Income).date;

  String _incomeLabel(Income i) => i.note.isEmpty ? 'Income received' : i.note;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final allExpenses = expenseProvider.expenses;
    final allIncome = expenseProvider.income;
    final query = _searchQuery.toLowerCase();

    // Income has no type/category: it shows under "All" and "Income" only.
    final showExpenses = _selectedType != _incomeChip;
    final showIncome = _selectedType == 'All' || _selectedType == _incomeChip;

    // Filter logic based on Search Query and Selected Category Filter
    final filteredExpenses = !showExpenses
        ? <Expense>[]
        : allExpenses.where((expense) {
            final matchesSearch = expense.title.toLowerCase().contains(query);
            final matchesType = _selectedType == 'All' || expense.type == _selectedType;
            final matchesCategory = _selectedCategory == 'All' || expense.category == _selectedCategory;
            return matchesSearch && matchesType && matchesCategory;
          }).toList();

    final filteredIncome = !showIncome
        ? <Income>[]
        : allIncome.where((i) => _incomeLabel(i).toLowerCase().contains(query)).toList();

    // Group expenses + income by Date, newest first within each day
    final Map<String, List<Object>> groupedEntries = {};
    for (final expense in filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedEntries.putIfAbsent(dateKey, () => []).add(expense);
    }
    for (final income in filteredIncome) {
      final dateKey = DateFormat('yyyy-MM-dd').format(income.date);
      groupedEntries.putIfAbsent(dateKey, () => []).add(income);
    }
    for (final list in groupedEntries.values) {
      list.sort((a, b) => _entryDate(b).compareTo(_entryDate(a)));
    }

    final sortedDates = groupedEntries.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                children: [
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track and search your expenses and income',
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
                          Icon(Icons.search, color: labelColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search (e.g., Pizza, Jeepney, Allowance)',
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
                    child: Icon(Icons.tune, color: labelColor, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Type filter chips (All / Food / Transportation / Other)
            _buildChipRow(
              items: [
                {'label': 'All', 'icon': ''},
                ...CategoryData.types.map((t) => {'label': t.name, 'icon': t.emoji}),
                {'label': _incomeChip, 'icon': '💰'},
              ],
              selected: _selectedType,
              countFor: (label) {
                if (label == 'All') return allExpenses.length + allIncome.length;
                if (label == _incomeChip) return allIncome.length;
                return allExpenses.where((e) => e.type == label).length;
              },
              onSelect: (label) => setState(() {
                _selectedType = label;
                _selectedCategory = 'All';
              }),
            ),

            // Subcategory chips (only once a type is picked)
            if (_selectedType != 'All' && _selectedType != _incomeChip) ...[
              const SizedBox(height: 8),
              _buildChipRow(
                items: [
                  {'label': 'All', 'icon': ''},
                  ...CategoryData.typeByName(_selectedType)
                      .subCategories
                      .map((s) => {'label': s.label, 'icon': s.emoji}),
                ],
                selected: _selectedCategory,
                countFor: (label) {
                  final inType = allExpenses.where((e) => e.type == _selectedType);
                  return label == 'All'
                      ? inType.length
                      : inType.where((e) => e.category == label).length;
                },
                onSelect: (label) => setState(() => _selectedCategory = label),
              ),
            ],
            const SizedBox(height: 16),

            // Expense Cards Grouped by Date
            Expanded(
              child: sortedDates.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing found',
                        style: TextStyle(color: labelColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final dateStr = sortedDates[index];
                        final entries = groupedEntries[dateStr]!;
                        final totalSpent = entries
                            .whereType<Expense>()
                            .fold(0.0, (sum, item) => sum + item.amount);
                        final totalReceived = entries
                            .whereType<Income>()
                            .fold(0.0, (sum, item) => sum + item.amount);

                        return _buildDateCardGroup(dateStr, entries, totalSpent, totalReceived);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Horizontally scrolling row of filter chips with counts
  Widget _buildChipRow({
    required List<Map<String, String>> items,
    required String selected,
    required int Function(String label) countFor,
    required void Function(String label) onSelect,
  }) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final label = item['label']!;
          final icon = item['icon']!;
          final isSelected = selected == label;

          return GestureDetector(
            onTap: () => onSelect(label),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : lightBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (icon.isNotEmpty) ...[
                    Text(icon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : darkTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${countFor(label)})',
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
    );
  }

  Widget _buildDateCardGroup(
    String dateStr,
    List<Object> items,
    double totalSpent,
    double totalReceived,
  ) {
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
                      style: TextStyle(
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(fontSize: 12, color: labelColor),
                  ),
                ),
              ],
            ),
          ),

          // Items Container
          Container(
            color: AppColors.surface,
            child: Column(
              children: items.map((entry) {
                if (entry is Expense) return _buildExpenseRow(entry);
                return _buildIncomeRow(entry as Income);
              }).toList(),
            ),
          ),

          // Daily footer: total spent and/or total received that day
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.greenFaint, // Soft green tint
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                if (totalSpent > 0 || totalReceived == 0)
                  _footerRow('Daily Total', '₱${totalSpent.toStringAsFixed(2)}'),
                if (totalSpent > 0 && totalReceived > 0) const SizedBox(height: 6),
                if (totalReceived > 0)
                  _footerRow('Received', '+₱${totalReceived.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeRow(Income income) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add_card, size: 20, color: AppColors.greenDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _incomeLabel(income),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Income',
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Received',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.greenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '+₱${income.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.greenDark,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: cardBorderColor),
      ],
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    // Icon & colour come from the expense's type / subcategory
    final iconEmoji = CategoryData.emojiFor(expense.category);
    final iconBg = CategoryData.typeOfCategory(expense.category).softBg;

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
                      style: TextStyle(
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
                          style: TextStyle(fontSize: 12, color: labelColor),
                        ),
                        const SizedBox(width: 6),
                        // Payment Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: lightBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            expense.paymentMethod,
                            style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (expense.fromSavings) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Savings',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.greenDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Text(
                '₱${expense.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: cardBorderColor),
      ],
    );
  }
}