import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import 'edit_budget_modal.dart';
import '../widgets/daily_limit_widgets.dart';
import '../widgets/savings_view.dart';

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
              color: selected ? Colors.white : Colors.transparent,
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
                color: selected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          pill('Budget', !_showSavings, () => setState(() => _showSavings = false)),
          pill(
            'Savings • ₱${provider.savingsBalance.toStringAsFixed(0)}',
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
    final amount = carry.abs().toStringAsFixed(0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start fresh?'),
        content: Text(
          'This clears the ₱$amount carried over, so you begin ${_thisPeriodLabel(type)} '
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
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
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
    final amount = carry.abs().toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '−₱$amount',
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
            'You ended ${_previousPeriodLabel(type)} ₱$amount over budget, so what you '
            'can spend ${_thisPeriodLabel(type)} (and your daily limit) is ₱$amount lower.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _confirmFreshStart(context, provider, carry, type),
              child: const Text(
                'Start fresh',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
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
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final now = DateTime.now();
        final cycleType = provider.cycleType;
        final cycleStart = provider.currentCycleStart(now);
        final cycleEnd = provider.currentCycleEnd(now);

        final budget = provider.getBudgetForCycle(now);
        final totalSpent = provider.totalSpentForCycle(now);
        final remaining = (budget - totalSpent) < 0 ? 0.0 : (budget - totalSpent);
        final percentage = budget == 0 ? 0.0 : (totalSpent / budget).clamp(0.0, 1.0);
        final percentageInt = (percentage * 100).toInt();
        final carry = provider.carryoverInto(now);

        if (_showSavings) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Management',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Plan and monitor your food allowance',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => EditBudgetModal.show(context),
                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF00C853)),
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
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEFEFEF)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_periodHeaderLabel(cycleType, cycleStart)} BUDGET STATUS',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
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
                              percentage > 0.8 ? Colors.red : const Color(0xFFFFB300),
                            ),
                            backgroundColor: const Color(0xFFE0E0E0),
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
                            const Text(
                              'BUDGET USED',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
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
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '₱${remaining.toStringAsFixed(0)} left',
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
                        _buildStatColumn(_budgetStatLabel(cycleType), '₱${budget.toStringAsFixed(0)}', Colors.black),
                        _buildStatColumn('SPENT', '₱${totalSpent.toStringAsFixed(0)}', const Color(0xFFFF8F00)),
                        _buildStatColumn('REMAINING', '₱${remaining.toStringAsFixed(0)}', const Color(0xFF00C853)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Available-to-spend vs. real cash on hand — deliberately two
              // separate numbers, since income/carryover can make them differ.
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      label: 'AVAILABLE THIS CYCLE',
                      value: provider.availableThisCycle(now),
                      caption: 'Budget + income − spent, incl. carryover',
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
                    color: const Color(0xFFFFFDE7),
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
                              border: Border.all(color: Colors.black87),
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
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
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

              // Suggested pace for the rest of the current cycle
              Builder(builder: (context) {
                final today = DateTime(now.year, now.month, now.day);
                final daysRemaining = (cycleEnd.difference(today).inDays + 1).clamp(1, 999);
                final recommendedDaily = remaining / daysRemaining;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_available, size: 16, color: Color(0xFF00C853)),
                              SizedBox(width: 8),
                              Text(
                                'SUGGESTED DAILY SPEND',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₱${recommendedDaily.toStringAsFixed(0)}',
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
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Spending ₱${recommendedDaily.toStringAsFixed(0)} or less per day ensures you won\'t run out of food money before this period ends!',
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Campus Budget Tips Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Text('🧡', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 6),
                        Text(
                          'CAMPUS BUDGET TIPS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    _BudgetTipRow(
                      title: 'Silog & Canteen Combos: ',
                      body: 'Pair rice plates with water to keep lunch under ₱100.',
                    ),
                    SizedBox(height: 8),
                    _BudgetTipRow(
                      title: 'GCash Cashback: ',
                      body: 'Look out for student canteen QR promos for 5–10% vouchers.',
                    ),
                    SizedBox(height: 8),
                    _BudgetTipRow(
                      title: 'Merienda Limit: ',
                      body: 'Cap mid-afternoon milk tea or snacks to 3 times a week.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
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
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 10, color: Colors.black45, height: 1.3),
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
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
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

class _BudgetTipRow extends StatelessWidget {
  final String title;
  final String body;

  const _BudgetTipRow({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✓ ', style: TextStyle(fontSize: 12, color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              children: [
                TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}