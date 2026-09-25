import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _selectedType = 'All';
  String _selectedCategory = 'All';

  // Filter & sort (opened from the tune button next to the search bar)
  int _dateFilter = 0; // 0 All time, 1 Today, 2 This week, 3 This month, 4 Custom
  DateTimeRange? _customRange;
  String _paymentFilter = 'All';
  int _sort = 0; // 0 Newest first, 1 Oldest first, 2 Biggest days first

  static const _dateLabels = ['All time', 'Today', 'This week', 'This month', 'Custom range'];
  static const _sortLabels = ['Newest first', 'Oldest first', 'Biggest days first'];
  static const _paymentOptions = ['All', 'Cash', 'GCash', 'Card'];

  bool get _hasActiveFilters =>
      _dateFilter != 0 || _paymentFilter != 'All' || _sort != 0;

  bool _matchesDate(Expense e) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(e.date.year, e.date.month, e.date.day);

    switch (_dateFilter) {
      case 1:
        return day == today;
      case 2:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return !day.isBefore(start) &&
            day.isBefore(start.add(const Duration(days: 7)));
      case 3:
        return e.date.year == now.year && e.date.month == now.month;
      case 4:
        final r = _customRange;
        if (r == null) return true;
        final start = DateTime(r.start.year, r.start.month, r.start.day);
        final end = DateTime(r.end.year, r.end.month, r.end.day);
        return !day.isBefore(start) && !day.isAfter(end);
      default:
        return true;
    }
  }

  // Theme Colors
  static const primaryGreen = Color(0xFF00C853);
  static const darkTextColor = Color(0xFF1E293B);
  static const labelColor = Color(0xFF64748B);
  static const lightBgColor = Color(0xFFF8FAFC);
  static const cardBorderColor = Color(0xFFF1F5F9);


  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final allExpenses = expenseProvider.expenses;

    // Filter logic based on Search Query and Selected Category Filter
    final filteredExpenses = allExpenses.where((expense) {
      final matchesSearch = expense.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'All' || expense.type == _selectedType;
      final matchesCategory = _selectedCategory == 'All' || expense.category == _selectedCategory;
      final matchesDate = _matchesDate(expense);
      final matchesPayment =
          _paymentFilter == 'All' || expense.paymentMethod == _paymentFilter;
      return matchesSearch && matchesType && matchesCategory && matchesDate && matchesPayment;
    }).toList();

    // Group expenses by Date
    final Map<String, List<Expense>> groupedExpenses = {};
    for (var expense in filteredExpenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
    }

    // Order of the day cards, and of the items inside each day
    final sortedDates = groupedExpenses.keys.toList();
    double dayTotal(String key) =>
        groupedExpenses[key]!.fold(0.0, (sum, e) => sum + e.amount);

    if (_sort == 1) {
      sortedDates.sort((a, b) => a.compareTo(b)); // oldest first
    } else if (_sort == 2) {
      sortedDates.sort((a, b) => dayTotal(b).compareTo(dayTotal(a))); // biggest days first
    } else {
      sortedDates.sort((a, b) => b.compareTo(a)); // newest first
    }

    for (final items in groupedExpenses.values) {
      if (_sort == 1) {
        items.sort((a, b) => a.date.compareTo(b.date));
      } else if (_sort == 2) {
        items.sort((a, b) => b.amount.compareTo(a.amount));
      } else {
        items.sort((a, b) => b.date.compareTo(a.date));
      }
    }

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
                    'Track, search, and manage all your past expenses',
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
                                hintText: 'Search expenses (e.g., Pizza, Jeepney)',
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
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _hasActiveFilters ? const Color(0xFFDCFCE7) : lightBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasActiveFilters ? primaryGreen : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: _hasActiveFilters ? primaryGreen : labelColor,
                        size: 20,
                      ),
                    ),
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
              ],
              selected: _selectedType,
              countFor: (label) => label == 'All'
                  ? allExpenses.length
                  : allExpenses.where((e) => e.type == label).length,
              onSelect: (label) => setState(() {
                _selectedType = label;
                _selectedCategory = 'All';
              }),
            ),

            // Subcategory chips (only once a type is picked)
            if (_selectedType != 'All') ...[
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
            if (_hasActiveFilters) _buildActiveFiltersBar(filteredExpenses.length),
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

  // ---- Filter & sort sheet -------------------------------------------------
  Future<void> _showFilterSheet() async {
    int dateFilter = _dateFilter;
    DateTimeRange? range = _customRange;
    String payment = _paymentFilter;
    int sort = _sort;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget chip(String label, bool selected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? primaryGreen : lightBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : darkTextColor,
                    ),
                  ),
                ),
              );
            }

            Widget section(String title) => Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                );

            final r = range;
            final customLabel = (dateFilter == 4 && r != null)
                ? '${DateFormat('MMM d').format(r.start)} – ${DateFormat('MMM d').format(r.end)}'
                : 'Custom range';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter & Sort',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() {
                            dateFilter = 0;
                            range = null;
                            payment = 'All';
                            sort = 0;
                          }),
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    section('DATE'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 4; i++)
                          chip(_dateLabels[i], dateFilter == i, () => setSheet(() => dateFilter = i)),
                        chip(customLabel, dateFilter == 4, () async {
                          final picked = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            initialDateRange: range,
                          );
                          if (picked != null) {
                            setSheet(() {
                              range = picked;
                              dateFilter = 4;
                            });
                          }
                        }),
                      ],
                    ),

                    section('PAYMENT METHOD'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _paymentOptions)
                          chip(m, payment == m, () => setSheet(() => payment = m)),
                      ],
                    ),

                    section('SORT BY'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _sortLabels.length; i++)
                          chip(_sortLabels[i], sort == i, () => setSheet(() => sort = i)),
                      ],
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            // "Custom range" with no dates picked = no date filter
                            _dateFilter = (dateFilter == 4 && range == null) ? 0 : dateFilter;
                            _customRange = range;
                            _paymentFilter = payment;
                            _sort = sort;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Summary line shown under the chips while a filter/sort is active
  Widget _buildActiveFiltersBar(int resultCount) {
    final parts = <String>[];
    final r = _customRange;
    if (_dateFilter == 4 && r != null) {
      parts.add('${DateFormat('MMM d').format(r.start)} – ${DateFormat('MMM d').format(r.end)}');
    } else if (_dateFilter != 0) {
      parts.add(_dateLabels[_dateFilter]);
    }
    if (_paymentFilter != 'All') parts.add(_paymentFilter);
    if (_sort != 0) parts.add(_sortLabels[_sort]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$resultCount found • ${parts.join(' • ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: labelColor),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _dateFilter = 0;
              _customRange = null;
              _paymentFilter = 'All';
              _sort = 0;
            }),
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
    // Icon & colour come from the expense's type / subcategory
    final iconEmoji = CategoryData.emojiFor(expense.category);
    final iconBg = CategoryData.typeOfCategory(expense.category).softColor;

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
                        Flexible(
                          child: Text(
                            '${expense.category}  •  ${DateFormat('hh:mm a').format(expense.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: labelColor),
                          ),
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
                            style: const TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
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