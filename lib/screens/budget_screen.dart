import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import 'edit_budget_modal.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        final percentage = provider.budgetPercentage;
        final percentageInt = provider.budgetPercentageInt;
        final totalSpent = provider.totalSpent;
        final remaining = provider.remainingBudget;
        final monthlyBudget = provider.monthlyBudget;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
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
                      '${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()} BUDGET STATUS',
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
                        _buildStatColumn('MONTHLY', '₱${monthlyBudget.toStringAsFixed(0)}', Colors.black),
                        _buildStatColumn('SPENT', '₱${totalSpent.toStringAsFixed(0)}', const Color(0xFFFF8F00)),
                        _buildStatColumn('REMAINING', '₱${remaining.toStringAsFixed(0)}', const Color(0xFF00C853)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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

              // Recommended Daily Limit Card
              Builder(builder: (context) {
                final now = DateTime.now();
                final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                final daysRemaining = (daysInMonth - now.day + 1).clamp(1, daysInMonth);
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
                          Row(
                            children: [
                              const Icon(Icons.event_available, size: 16, color: Color(0xFF00C853)),
                              const SizedBox(width: 8),
                              Text(
                                'RECOMMENDED DAILY LIMIT',
                                style: const TextStyle(
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
                              'Spending ₱${recommendedDaily.toStringAsFixed(0)} or less per day ensures you won\'t run out of food money before the month ends!',
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