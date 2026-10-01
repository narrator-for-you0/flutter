import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_modal.dart';
import '../themes/app_colors.dart';

/// Unspent money from finished periods, and what you've spent out of it.
/// Shown under the "Savings" side of the Budget tab's switch.
class SavingsView extends StatelessWidget {
  const SavingsView({super.key});

  static const _green = Color(0xFF00C853);
  static Color get _greenDark => AppColors.greenDark;
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;
  static const _red = Color(0xFFDC2626);
  static Color get _blue => AppColors.blue;

  String _periodLabel(AllowanceCycleType type, SavingsCycle c) {
    if (type == AllowanceCycleType.monthly) {
      return DateFormat('MMMM yyyy').format(c.start);
    }
    return '${DateFormat('MMM d').format(c.start)} – ${DateFormat('MMM d').format(c.end)}';
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final canTrack = provider.canTrackSavings;
        final history = provider.savingsHistory();
        final earned = history.fold(0.0, (sum, c) => sum + c.saved);
        final spent = provider.totalSavingsSpent;
        final balance = provider.savingsBalance;
        final withdrawals = provider.savingsWithdrawals;
        final recent = history.reversed.take(12).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(balance, earned, spent),
            const SizedBox(height: 12),

            if (balance > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => AddExpenseModal.show(context, startFromSavings: true),
                  icon: const Icon(Icons.savings_outlined, size: 18, color: _green),
                  label: const Text(
                    'Spend from savings',
                    style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            if (balance > 0) const SizedBox(height: 16),

            if (!canTrack)
              _infoCard(
                'Set a budget to start saving',
                'Savings are the unspent part of each finished period\'s budget. '
                    'Once you\'ve set a budget (Budget view → Edit), leftovers from '
                    'finished periods will show up here.',
              )
            else if (history.isEmpty)
              _infoCard(
                'Nothing saved yet',
                'Your first savings appear when the current period ends — whatever '
                    'you haven\'t spent by then moves here.',
              ),

            if (recent.isNotEmpty) ...[
              _sectionLabel('BY PERIOD'),
              const SizedBox(height: 8),
              ...recent.map((c) => _periodRow(provider.cycleType, c)),
              const SizedBox(height: 16),
            ],

            if (withdrawals.isNotEmpty) ...[
              _sectionLabel('SPENT FROM SAVINGS'),
              const SizedBox(height: 4),
              Text(
                'Tap one to edit it',
                style: TextStyle(fontSize: 10, color: _muted),
              ),
              const SizedBox(height: 8),
              ...withdrawals.map((e) => _withdrawalRow(context, e)),
            ] else if (balance > 0) ...[
              Text(
                'Turn on "Pay from savings" when you add an expense, or use the '
                'button above. Those expenses won\'t count against your budget or '
                'daily limit.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _heroCard(double balance, double earned, double spent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'TOTAL SAVINGS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₱${balance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat('SAVED', '₱${earned.toStringAsFixed(0)}'),
              const SizedBox(width: 10),
              _heroStat('SPENT', '₱${spent.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: _muted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoCard(String title, String body) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark),
          ),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 12, color: _muted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _periodRow(AllowanceCycleType type, SavingsCycle c) {
    final String amountText;
    final Color amountColor;
    if (c.leftover > 0) {
      amountText = '+₱${c.leftover.toStringAsFixed(0)}';
      amountColor = _greenDark;
    } else if (c.leftover < 0) {
      amountText = 'Over by ₱${c.leftover.abs().toStringAsFixed(0)}';
      amountColor = _red;
    } else {
      amountText = '₱0';
      amountColor = _muted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _periodLabel(type, c),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _dark),
            ),
          ),
          Text(
            amountText,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: amountColor),
          ),
        ],
      ),
    );
  }

  Widget _withdrawalRow(BuildContext context, Expense e) {
    final type = CategoryData.typeOfCategory(e.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => AddExpenseModal.show(context, existing: e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: type.softBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    CategoryData.emojiFor(e.category),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('MMM d').format(e.date)} • ${e.category}',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '−₱${e.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}