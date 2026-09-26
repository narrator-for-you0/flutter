import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_modal.dart';
import '../screens/add_income_modal.dart';

const _weekdayShortNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// Month calendar showing how much was spent each day.
/// Day colours are relative to the daily limit:
///   green = under half, amber = 50-100%, red = over the limit.
class SpendingCalendar extends StatefulWidget {
  const SpendingCalendar({super.key});

  @override
  State<SpendingCalendar> createState() => _SpendingCalendarState();
}

class _SpendingCalendarState extends State<SpendingCalendar> {
  static const _primaryGreen = Color(0xFF00C853);
  static const _dark = Color(0xFF1E293B);
  static const _muted = Color(0xFF94A3B8);
  static const _red = Color(0xFFDC2626);
  static const _gold = Color(0xFFCA8A04);

  late DateTime _month; // first day of the visible month
  late DateTime _selected;

  /// null = all types. Otherwise filters the grid + the day panel.
  ExpenseType? _typeFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _goToMonth(DateTime target) {
    final now = DateTime.now();
    final month = DateTime(target.year, target.month);
    setState(() {
      _month = month;
      // Select today if we're on the current month, otherwise the 1st.
      _selected = DateUtils.isSameMonth(month, now)
          ? DateTime(now.year, now.month, now.day)
          : month;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) _goToMonth(picked);
  }

  /// Swipe left -> next month, swipe right -> previous month.
  void _onGridSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    _goToMonth(DateTime(_month.year, _month.month + (v < 0 ? 1 : -1)));
  }

  /// After adding/editing, follow the expense to its date so it stays visible.
  void _followSavedDate(DateTime? saved) {
    if (saved == null || !mounted) return;
    setState(() {
      _month = DateTime(saved.year, saved.month);
      _selected = DateTime(saved.year, saved.month, saved.day);
    });
  }

  Future<void> _openAdd() async {
    final saved = await AddExpenseModal.show(context, initialDate: _selected);
    _followSavedDate(saved);
  }

  Future<void> _openEdit(Expense e) async {
    final saved = await AddExpenseModal.show(context, existing: e);
    _followSavedDate(saved);
  }

  Future<void> _openAddIncome() async {
    final saved = await AddIncomeModal.show(context, initialDate: _selected);
    _followSavedDate(saved);
  }

  Future<void> _openEditIncome(Income income) async {
    final saved = await AddIncomeModal.show(context, existing: income);
    _followSavedDate(saved);
  }

  void _deleteIncome(Income income) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    provider.deleteIncome(income);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted income (₱${income.amount.toStringAsFixed(2)})'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFF69F0AE),
            onPressed: () => provider.restoreIncome(income),
          ),
        ),
      );
  }

  void _delete(Expense e) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    provider.deleteExpense(e);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${e.title} (₱${e.amount.toStringAsFixed(2)})'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFF69F0AE),
            onPressed: () => provider.restoreExpense(e),
          ),
        ),
      );
  }

  /// Weeks (Monday-first) for the visible month. Each week has exactly 7
  /// entries; days outside the month are null.
  List<List<DateTime?>> _buildWeeks(int daysInMonth, int leading) {
    final cells = <DateTime?>[
      ...List.filled(leading, null),
      ...List.generate(daysInMonth, (i) => DateTime(_month.year, _month.month, i + 1)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return List.generate(cells.length ~/ 7, (w) => cells.sublist(w * 7, w * 7 + 7));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final totals = provider.getDailyTotalsForMonth(_month, type: _typeFilter);
        final limit = provider.dailyLimitFor(_month);
        final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
        // Monday-first grid (matches the app's "This Week" logic)
        final leading = _month.weekday - 1;
        final weeks = _buildWeeks(daysInMonth, leading);

        final monthTotal = totals.values.fold(0.0, (a, b) => a + b);
        final daysOver = totals.values.where((v) => v > limit).length;

        MapEntry<int, double>? worstDay;
        MapEntry<int, double>? bestDay;
        for (final e in totals.entries) {
          if (worstDay == null || e.value > worstDay!.value) worstDay = e;
          if (bestDay == null || e.value < bestDay!.value) bestDay = e;
        }

        final lastMonth = DateTime(_month.year, _month.month - 1);
        final lastMonthTotal = provider.totalSpentForMonth(lastMonth);
        final streak = provider.currentUnderLimitStreak;
        final busiest = provider.busiestWeekday;
        final typeTotals = provider.typeTotalsForMonth(_month);
        final incomeTotals = provider.getIncomeTotalsForMonth(_month);
        final runwayDate = provider.projectedRunwayDate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 14),
                  _buildSummaryRow(monthTotal, daysOver, worstDay, bestDay),
                  const SizedBox(height: 10),
                  _buildInsights(lastMonthTotal, monthTotal, streak, busiest),
                  if (typeTotals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildTypeTotalsRow(typeTotals),
                  ],
                  const SizedBox(height: 14),
                  _buildTypeFilterChips(),
                  const SizedBox(height: 12),
                  _buildWeekdayLabels(),
                  const SizedBox(height: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _onGridSwipe,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        key: ValueKey(Object.hash(_month, _typeFilter)),
                        children: weeks
                            .map((week) => _buildWeekRow(
                                  week,
                                  totals,
                                  limit,
                                  provider,
                                  worstDay,
                                  bestDay,
                                  incomeTotals,
                                  runwayDate,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLegend(limit, runwayDate != null),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe left or right to change month',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectedDayPanel(provider, limit),
          ],
        );
      },
    );
  }

  // ---- header --------------------------------------------------------------
  Widget _buildMonthHeader() {
    final isCurrentMonth = DateUtils.isSameMonth(_month, DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navButton(Icons.chevron_left, () => _goToMonth(DateTime(_month.year, _month.month - 1))),
        Expanded(
          child: GestureDetector(
            onTap: _pickMonth,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _dark,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: _muted),
                  ],
                ),
                if (!isCurrentMonth)
                  GestureDetector(
                    onTap: () => _goToMonth(DateTime.now()),
                    child: const Text(
                      'Back to this month',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _navButton(Icons.chevron_right, () => _goToMonth(DateTime(_month.year, _month.month + 1))),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildSummaryRow(
    double total,
    int daysOver,
    MapEntry<int, double>? worstDay,
    MapEntry<int, double>? bestDay,
  ) {
    return Row(
      children: [
        _summaryTile('MONTH TOTAL', '₱${total.toStringAsFixed(0)}', _dark),
        const SizedBox(width: 8),
        _summaryTile(
          'DAYS OVER LIMIT',
          '$daysOver',
          daysOver > 0 ? _red : _primaryGreen,
        ),
        const SizedBox(width: 8),
        _summaryTile(
          'WORST DAY',
          worstDay == null
              ? '–'
              : DateFormat('MMM d').format(DateTime(_month.year, _month.month, worstDay.key)),
          _red,
          subtitle: worstDay == null ? null : '₱${worstDay.value.toStringAsFixed(0)}',
        ),
        const SizedBox(width: 8),
        _summaryTile(
          'BEST DAY',
          bestDay == null
              ? '–'
              : DateFormat('MMM d').format(DateTime(_month.year, _month.month, bestDay.key)),
          const Color(0xFF15803D),
          subtitle: bestDay == null ? null : '₱${bestDay.value.toStringAsFixed(0)}',
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, Color valueColor, {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: _muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            if (subtitle != null)
              Text(subtitle, style: const TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      ),
    );
  }

  // ---- insights & type totals ------------------------------------------------
  Widget _buildInsights(
    double lastMonthTotal,
    double monthTotal,
    int streak,
    MapEntry<int, double>? busiest,
  ) {
    final chips = <Widget>[];

    if (lastMonthTotal > 0) {
      final diff = monthTotal - lastMonthTotal;
      final isMore = diff > 0;
      final label = diff == 0
          ? 'Same as ${DateFormat('MMMM').format(DateTime(_month.year, _month.month - 1))} so far'
          : '₱${diff.abs().toStringAsFixed(0)} ${isMore ? 'more' : 'less'} than '
              '${DateFormat('MMMM').format(DateTime(_month.year, _month.month - 1))}';
      chips.add(_insightChip(Icons.trending_up, label, isMore ? _red : const Color(0xFF15803D)));
    }

    if (streak >= 2) {
      chips.add(_insightChip(Icons.local_fire_department, '$streak day streak under your limit', const Color(0xFFEA580C)));
    }

    if (busiest != null && busiest.value > 0) {
      final name = _weekdayShortNames[busiest.key - 1];
      chips.add(_insightChip(Icons.calendar_today, 'You spend the most on ${name}s', _dark));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _insightChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildTypeTotalsRow(Map<String, double> typeTotals) {
    return Row(
      children: CategoryData.types.map((t) {
        final amount = typeTotals[t.name] ?? 0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: t == CategoryData.types.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.softColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('${t.emoji} ${t.name}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: t.color)),
                const SizedBox(height: 2),
                Text('₱${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _dark)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---- type filter chips -----------------------------------------------------
  Widget _buildTypeFilterChips() {
    Widget chip(String label, String emoji, Color color, Color soft, ExpenseType? type) {
      final isSelected = _typeFilter?.name == type?.name;
      return GestureDetector(
        onTap: () => setState(() => _typeFilter = isSelected ? null : type),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : soft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Text(
            '$emoji $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', '📋', _dark, const Color(0xFFF1F5F9), null),
          ...CategoryData.types.map((t) => chip(t.name, t.emoji, t.color, t.softColor, t)),
        ],
      ),
    );
  }

  // ---- grid ----------------------------------------------------------------
  Widget _buildWeekdayLabels() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        ...labels.map((l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _muted,
                  ),
                ),
              ),
            )),
        const SizedBox(
          width: 40,
          child: Center(
            child: Text(
              '∑',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekRow(
    List<DateTime?> week,
    Map<int, double> totals,
    double limit,
    ExpenseProvider provider,
    MapEntry<int, double>? worstDay,
    MapEntry<int, double>? bestDay,
    Map<int, double> incomeTotals,
    DateTime? runwayDate,
  ) {
    final weekTotal = week
        .where((d) => d != null)
        .fold(0.0, (sum, d) => sum + (totals[d!.day] ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 74,
        child: Row(
          children: [
            ...week.map((date) {
              if (date == null) return const Expanded(child: SizedBox.shrink());
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildDayCell(
                    date,
                    totals[date.day] ?? 0,
                    limit,
                    provider,
                    isWorst: worstDay != null && date.day == worstDay.key,
                    isBest: bestDay != null && date.day == bestDay.key,
                    hasIncome: (incomeTotals[date.day] ?? 0) > 0,
                    isPastRunway: runwayDate != null && date.isAfter(runwayDate),
                  ),
                ),
              );
            }),
            Container(
              width: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                weekTotal > 0 ? _compact(weekTotal) : '–',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    double amount,
    double limit,
    ExpenseProvider provider, {
    required bool isWorst,
    required bool isBest,
    required bool hasIncome,
    required bool isPastRunway,
  }) {
    final isSelected = DateUtils.isSameDay(date, _selected);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final ratio = limit > 0 ? amount / limit : 0.0;
    final isFuture = date.isAfter(DateTime.now());
    // Shortfall shading only makes sense for days that haven't happened yet.
    final showShortfall = isFuture && isPastRunway && amount == 0;
    final noSpend = !isFuture && _typeFilter == null && provider.isNoSpendDay(date);
    final inStreak = !isFuture &&
        _typeFilter == null &&
        date.isAfter(DateTime.now().subtract(Duration(days: provider.currentUnderLimitStreak)));

    Color bg = showShortfall ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC);
    Color amountColor = _muted;
    if (amount > 0) {
      if (ratio > 1) {
        bg = const Color(0xFFFEE2E2);
        amountColor = _red;
      } else if (ratio >= 0.5) {
        bg = const Color(0xFFFEF3C7);
        amountColor = const Color(0xFFB45309);
      } else {
        bg = const Color(0xFFDCFCE7);
        amountColor = const Color(0xFF15803D);
      }
    }

    Color borderColor = isSelected
        ? _primaryGreen
        : (isToday ? _primaryGreen.withValues(alpha: 0.45) : Colors.transparent);
    double borderWidth = isSelected ? 2 : 1.5;
    if (!isSelected && isWorst) {
      borderColor = _red;
      borderWidth = 1.5;
    } else if (!isSelected && isBest) {
      borderColor = _gold;
      borderWidth = 1.5;
    }

    return Tooltip(
      waitDuration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      richMessage: _buildDayTooltip(date, provider),
      child: GestureDetector(
      onTap: () => setState(() => _selected = date),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.w500,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount > 0 ? _compact(amount) : '',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
          if (isBest)
            const Positioned(top: -4, right: -2, child: Text('⭐', style: TextStyle(fontSize: 11))),
          if (isWorst)
            const Positioned(top: -4, right: -2, child: Text('⚠️', style: TextStyle(fontSize: 11))),
          if (hasIncome)
            Positioned(
              top: -3,
              left: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: _primaryGreen, shape: BoxShape.circle),
                child: const Icon(Icons.add, size: 10, color: Colors.white),
              ),
            ),
          if (noSpend)
            Positioned(
              bottom: -3,
              left: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: _primaryGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            )
          else if (inStreak && amount > 0)
            const Positioned(bottom: -4, left: -2, child: Text('🔥', style: TextStyle(fontSize: 11))),
        ],
      ),
      ),
    );
  }

  /// Hover/long-press preview: what's actually behind a day's number.
  InlineSpan _buildDayTooltip(DateTime date, ExpenseProvider provider) {
    final items = provider.getExpensesOn(date);
    final incomeItems = provider.getIncomeOn(date);
    final total = items.fold(0.0, (sum, e) => sum + e.amount);
    final totalIncome = incomeItems.fold(0.0, (sum, i) => sum + i.amount);

    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white);
    const lineStyle = TextStyle(fontSize: 11.5, color: Colors.white, height: 1.5);
    const incomeStyle = TextStyle(fontSize: 11.5, color: Color(0xFF86EFAC), height: 1.5);
    const mutedStyle = TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.5);

    final children = <InlineSpan>[
      TextSpan(text: DateFormat('EEEE, MMM d').format(date), style: headerStyle),
    ];

    if (items.isEmpty && incomeItems.isEmpty) {
      children.add(const TextSpan(text: '\nNo activity logged', style: mutedStyle));
    } else {
      const maxLines = 5;
      for (final e in items.take(maxLines)) {
        children.add(TextSpan(
          text: '\n${CategoryData.emojiFor(e.category)} ${e.title} — ₱${e.amount.toStringAsFixed(0)}',
          style: lineStyle,
        ));
      }
      if (items.length > maxLines) {
        children.add(TextSpan(text: '\n+${items.length - maxLines} more', style: mutedStyle));
      }
      for (final i in incomeItems) {
        children.add(TextSpan(
          text: '\n+ ₱${i.amount.toStringAsFixed(0)}'
              '${i.note.isEmpty ? ' income' : ' • ${i.note}'}',
          style: incomeStyle,
        ));
      }
      children.add(TextSpan(
        text: '\nTotal: ₱${total.toStringAsFixed(0)}'
            '${totalIncome > 0 ? '  (+₱${totalIncome.toStringAsFixed(0)} in)' : ''}',
        style: headerStyle,
      ));
    }

    return TextSpan(children: children);
  }

  String _compact(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Widget _buildLegend(double limit, bool showRunway) {
    Widget dot(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 10, color: _muted)),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(const Color(0xFFDCFCE7), 'Under 50% of limit'),
        dot(const Color(0xFFFEF3C7), '50–100%'),
        dot(const Color(0xFFFEE2E2), 'Over ₱${limit.toStringAsFixed(0)}'),
        if (showRunway) dot(const Color(0xFFE2E8F0), 'Projected shortfall'),
      ],
    );
  }

  // ---- selected day --------------------------------------------------------
  Widget _buildSelectedDayPanel(ExpenseProvider provider, double limit) {
    final allItems = provider.getExpensesOn(_selected);
    final items = _typeFilter == null
        ? allItems
        : allItems.where((e) => e.type == _typeFilter!.name).toList();
    final total = allItems.fold(0.0, (sum, e) => sum + e.amount);
    final isOver = total > limit;
    final typeTotals = provider.typeTotalsForDay(_selected);
    final incomeItems = provider.getIncomeOn(_selected);
    final balance = provider.runningBalanceThrough(_selected);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_selected),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
              ),
              Text(
                '₱${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isOver ? _red : _dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Balance as of this day: ₱${balance.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: balance < 0 ? _red : _muted,
            ),
          ),
          if (incomeItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Tap income to edit • Swipe left to delete',
              style: TextStyle(fontSize: 10, color: _muted),
            ),
            const SizedBox(height: 6),
            ...incomeItems.map(_buildIncomeRow),
          ],
          if (allItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOver
                    ? '₱${(total - limit).toStringAsFixed(0)} over the ₱${limit.toStringAsFixed(0)} limit'
                    : '₱${(limit - total).toStringAsFixed(0)} under the ₱${limit.toStringAsFixed(0)} limit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isOver ? _red : const Color(0xFF15803D),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildDayTypeBar(typeTotals, total),
          ],
          const SizedBox(height: 12),
          if (_typeFilter != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Showing ${_typeFilter!.name} only',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _typeFilter!.color),
              ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                allItems.isEmpty ? 'No expenses on this day.' : 'No ${_typeFilter!.name} expenses on this day.',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Tap to edit • Swipe left to delete',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ),
            ...items.map(_buildExpenseRow),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.remove, size: 18, color: _primaryGreen),
                  label: Flexible(
                    child: Text(
                      'Expense • ${DateFormat('MMM d').format(_selected)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: _primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openAddIncome,
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                  label: const Flexible(
                    child: Text(
                      'Income',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeRow(Income income) {
    Widget deleteBackground() => Container(
          color: _red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: ValueKey('income-${income.id ?? identityHashCode(income)}'),
          direction: DismissDirection.endToStart,
          background: deleteBackground(),
          secondaryBackground: deleteBackground(),
          onDismissed: (_) => _deleteIncome(income),
          child: Material(
            color: const Color(0xFFEFF6FF),
            child: InkWell(
              onTap: () => _openEditIncome(income),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        income.note.isEmpty ? 'Income' : income.note,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
                      ),
                    ),
                    Text(
                      '+₱${income.amount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small proportional Food / Transportation / Other bar for the selected day.
  Widget _buildDayTypeBar(Map<String, double> typeTotals, double total) {
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: CategoryData.types.map((t) {
                final amount = typeTotals[t.name] ?? 0;
                if (amount <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: (amount * 1000).round().clamp(1, 1000000),
                  child: Container(color: t.color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: CategoryData.types.map((t) {
            final amount = typeTotals[t.name] ?? 0;
            if (amount <= 0) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${t.name} ₱${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: _muted)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExpenseRow(Expense e) {
    final type = CategoryData.typeOfCategory(e.category);

    Widget deleteBackground() => Container(
          color: _red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Dismissible(
          key: ValueKey('expense-${e.id ?? identityHashCode(e)}'),
          direction: DismissDirection.endToStart,
          background: deleteBackground(),
          secondaryBackground: deleteBackground(),
          onDismissed: (_) => _delete(e),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => _openEdit(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: type.softColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(CategoryData.emojiFor(e.category), style: const TextStyle(fontSize: 17)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.category} • ${DateFormat('h:mm a').format(e.date)} • ${e.paymentMethod}',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₱${e.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}