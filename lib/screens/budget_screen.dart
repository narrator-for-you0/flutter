import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/tips.dart';
import '../providers/expense_provider.dart';
import 'edit_budget_modal.dart';
import 'category_budget_modal.dart';
import 'recurring_expenses_screen.dart';
import '../widgets/daily_limit_widgets.dart';
import '../widgets/savings_view.dart';
import '../widgets/tip_card.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Budget | Savings switch at the top of this tab.
  bool _showSavings = false;

  Widget _modeSwitch(ExpenseProvider provider) {
    Widget pill(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          pill(
            'Budget',
            !_showSavings,
            () => setState(() => _showSavings = false),
          ),
          pill(
            'Savings â€¢ ${formatPeso(provider.savingsBalance, decimals: 0)}',
            _showSavings,
            () => setState(() => _showSavings = true),
          ),
        ],
      ),
    );
  }

  String _periodHeaderLabel(AllowanceCycleType type, DateTime cycleStart) {
    switch (type) {
      case AllowanceCycleType.monthly:
        return DateFormat('MMMM yyyy').format(cycleStart).toUpperCase();
      case AllowanceCycleType.weekly:
        return 'WEEK OF ${DateFormat('MMM d').format(cycleStart).toUpperCase()}';
      case AllowanceCycleType.biweekly:
        return '2 WEEKS FROM ${DateFormat('MMM d').format(cycleStart).toUpperCase()}';
    }
  }

  String _previousPeriodLabel(AllowanceCycleType type) {
    switch (type) {
      case AllowanceCycleType.monthly:
        return 'last month';
      case AllowanceCycleType.weekly:
        return 'last week';
      case AllowanceCycleType.biweekly:
        return 'the last 2 weeks';
    }
  }

  String _thisPeriodLabel(AllowanceCycleType type) {
    switch (type) {
      case AllowanceCycleType.monthly:
        return 'this month';
      case AllowanceCycleType.weekly:
        return 'this week';
      case AllowanceCycleType.biweekly:
        return 'these 2 weeks';
    }
  }

  Future<void> _confirmFreshStart(
    BuildContext context,
    ExpenseProvider provider,
    double carry,
    AllowanceCycleType type,
  ) async {
    final amount = formatPeso(carry.abs());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start fresh?'),
        content: Text(
          'This clears the $amount carried over, so you begin ${_thisPeriodLabel(type)} '
          'with your full budget. Your expense history stays exactly as it is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Start fresh',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final previous = provider.startFreshCarryover();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Carryover cleared'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFF69F0AE),
            onPressed: () => provider.restoreCarryoverFreshFrom(previous),
          ),
        ),
      );
  }

  Widget _carryoverCard(
    BuildContext context,
    ExpenseProvider provider,
    double carry,
    AllowanceCycleType type,
  ) {
    final amount = formatPeso(carry.abs());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.redBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.redo, size: 16, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CARRIED OVER FROM ${_previousPeriodLabel(type).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'âˆ’$amount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You ended ${_previousPeriodLabel(type)} $amount over budget, so what you '
            'can spend ${_thisPeriodLabel(type)} (and your daily limit) is $amount lower.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  _confirmFreshStart(context, provider, carry, type),
              child: const Text(
                'Start fresh',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _budgetStatLabel(AllowanceCycleType type) {
    switch (type) {
      case AllowanceCycleType.monthly:
        return 'MONTHLY';
      case AllowanceCycleType.weekly:
        return 'WEEKLY';
      case AllowanceCycleType.biweekly:
        return 'BIWEEKLY';
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final now = DateTime.now();
        final cycleType = provider.cycleType;
        final cycleStart = provider.currentCycleStart(now);
        final cycleEnd = provider.currentCycleEnd(now);

        final budget = provider.getBudgetForCycle(now);
        final totalSpent = provider.totalSpentForCycle(now);
        final remaining = (budget - totalSpent) < 0
            ? 0.0
            : (budget - totalSpent);
        final percentage = budget == 0
            ? 0.0
            : (totalSpent / budget).clamp(0.0, 1.0);
        final percentageInt = (percentage * 100).toInt();
        final carry = provider.carryoverInto(now);

        if (_showSavings) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _modeSwitch(provider),
                const SizedBox(height: 16),
                const SavingsView(),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _modeSwitch(provider),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Plan and monitor your food allowance',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => EditBudgetModal.show(context),
                    icon: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Color(0xFF00C853),
                    ),
                    label: const Text(
                      'Edit Budget',
                      style: TextStyle(color: Color(0xFF00C853), fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00C853)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Budget Circular Card Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderAlt),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_periodHeaderLabel(cycleType, cycleStart)} BUDGET STATUS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 150,
                          width: 150,
                          child: CircularProgressIndicator(
                            value: percentage,
                            strokeWidth: 16,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percentage > 0.8
                                  ? Colors.red
                                  : const Color(0xFFFFB300),
                            ),
                            backgroundColor: AppColors.trackAlt,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentageInt%',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'BUDGET USED',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.greyText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amberSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${formatPeso(remaining, decimals: 0)} left',
                                style: const TextStyle(
                                  color: Color(0xFFFF8F00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          _budgetStatLabel(cycleType),
                          formatPeso(budget, decimals: 0),
                          AppColors.strongText,
                        ),
                        _buildStatColumn(
                          'SPENT',
                          formatPeso(totalSpent, decimals: 0),
                          const Color(0xFFFF8F00),
                        ),
                        _buildStatColumn(
                          'REMAINING',
                          formatPeso(remaining, decimals: 0),
                          const Color(0xFF00C853),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Available-to-spend vs. real cash on hand â€” deliberately two
              // separate numbers, since income/carryover can make them differ.
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      label: 'AVAILABLE THIS CYCLE',
                      value: provider.availableThisCycle(now),
                      caption: 'Budget + income âˆ’ spent, incl. carryover',
                      accent: const Color(0xFF00C853),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      label: 'BALANCE',
                      value: provider.currentBalance,
                      caption: 'All income minus all spending, ever',
                      accent: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Shortfall from the previous period, if any.
              if (carry < 0) ...[
                _carryoverCard(context, provider, carry, cycleType),
                const SizedBox(height: 16),
              ],

              // Caution Banner (shows dynamically if over 75%)
              if (percentage >= 0.75)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoft2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEE58)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "You've used $percentageInt% of your\nbudget.",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.black87),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'CAUTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ve used over $percentageInt% of your allowance. Consider moderating extra expenses this week.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Today vs. daily limit (set the limit in Edit Budget)
              DailyLimitCard(
                spent: provider.todaySpent,
                limit: provider.dailyLimit,
              ),
              const SizedBox(height: 16),

              // Per-category caps for this period
              _categoryLimitsCard(context, provider, now),
              const SizedBox(height: 16),

              // Entry point to the recurring-expenses list
              _recurringCard(context, provider),
              const SizedBox(height: 16),

              // Suggested pace for the rest of the current cycle
              Builder(
                builder: (context) {
                  final today = DateTime(now.year, now.month, now.day);
                  final daysRemaining = (cycleEnd.difference(today).inDays + 1)
                      .clamp(1, 999);
                  final recommendedDaily = remaining / daysRemaining;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.greenFaint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.greenSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 16,
                                  color: Color(0xFF00C853),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'SUGGESTED DAILY SPEND',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.greenDeep,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              formatPeso(recommendedDaily, decimals: 0),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'To stay on budget for remaining $daysRemaining days',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.black45,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Spending ${formatPeso(recommendedDaily, decimals: 0)} or less per day ensures you won\'t run out of food money before this period ends!',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Campus Budget Tips Card (one tip per day; urgent advice when tight)
              TipCard(
                heading: 'CAMPUS BUDGET TIPS',
                emoji: 'ðŸ§¡',
                tips: campusTips,
                urgentTips: campusUrgentTips,
                isUrgent: isBudgetUrgent(spent: totalSpent, budget: budget),
                background: AppColors.orangeSoft,
                borderColor: AppColors.orangeBorder,
                headingColor: AppColors.orangeText,
                // Offset so this card doesn't land on the same tip as the
                // Saving Tips card on Home; both pools are the same length.
                offset: 5,
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryLimitsCard(
    BuildContext context,
    ExpenseProvider provider,
    DateTime now,
  ) {
    final statuses = provider.categoryBudgetStatuses(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pie_chart_outline,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CATEGORY LIMITS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => CategoryBudgetModal.show(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  statuses.isEmpty ? 'Set limits' : 'Edit',
                  style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (statuses.isEmpty)
            Text(
              'Cap how much you spend on Food, Transportation, or a specific '
              'category like Coffee each period. You\'ll get a heads-up when you pass one.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.black54,
                height: 1.4,
              ),
            )
          else ...[
            Text(
              'Resets every period',
              style: TextStyle(fontSize: 10, color: AppColors.black45),
            ),
            const SizedBox(height: 12),
            ...statuses.map(_categoryLimitRow),
          ],
        ],
      ),
    );
  }

  Widget _categoryLimitRow(CategoryBudgetStatus s) {
    final Color color;
    if (s.isOver) {
      color = const Color(0xFFDC2626);
    } else if (s.ratio >= 0.8) {
      color = const Color(0xFFFF8F00);
    } else {
      color = const Color(0xFF00C853);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                '${formatPeso(s.spent, decimals: 0)} / ${formatPeso(s.limit, decimals: 0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (s.isOver) ...[
            const SizedBox(height: 4),
            Text(
              '${formatPeso((-s.remaining), decimals: 0)} over',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recurringCard(BuildContext context, ExpenseProvider provider) {
    final activeCount = provider.recurringExpenses
        .where((r) => r.active)
        .length;

    return Material(
      color: AppColors.cardAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringExpensesScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderAlt),
          ),
          child: Row(
            children: [
              const Icon(Icons.repeat, size: 18, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECURRING EXPENSES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeCount == 0
                          ? 'Auto-log things like weekly load or printing'
                          : '$activeCount active â€¢ logged automatically when due',
                      style: TextStyle(fontSize: 11, color: AppColors.black54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.black54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required double value,
    required String caption,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.greyText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatPeso(value, decimals: 0),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.black45,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.greyText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
