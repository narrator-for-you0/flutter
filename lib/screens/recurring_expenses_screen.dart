import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_category.dart';
import '../models/recurring_expense.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';
import 'recurring_expense_modal.dart';

/// Brand green â€” identical in light and dark, so it stays const.
const _green = Color(0xFF00C853);

/// The list of recurring expenses: what repeats, when it repeats next, and a
/// switch to pause one without losing it.
class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final provider = context.watch<ExpenseProvider>();
    final rules = provider.recurringExpenses;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Recurring Expenses',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecurringExpenseModal.show(context),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: rules.isEmpty
          ? EmptyState(
              icon: Icons.repeat,
              title: 'Nothing repeats yet',
              message:
                  "Set up weekly load, a printing allowance, or anything else "
                  "that lands on a schedule and we'll log it for you.",
              accent: _green,
              badgeColor: AppColors.greenSoft,
              actionLabel: 'New recurring expense',
              onAction: () => RecurringExpenseModal.show(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RecurringTile(rule: rules[i]),
            ),
    );
  }
}

/// One row: name, amount, cadence, and when it logs next. Swipe left to delete
/// (with an undo), tap to edit, use the switch to pause.
class _RecurringTile extends StatelessWidget {
  final RecurringExpense rule;

  const _RecurringTile({required this.rule});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final type = CategoryData.typeOfCategory(rule.category);
    final next = rule.nextOccurrence(DateTime.now());
    final paused = !rule.active;

    return Dismissible(
      key: ValueKey(rule.id ?? rule.title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.redSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => _delete(context),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => RecurringExpenseModal.show(context, existing: rule),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: type.softBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(type.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              rule.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: paused
                                    ? AppColors.muted
                                    : AppColors.text,
                              ),
                            ),
                          ),
                          if (paused) ...[
                            const SizedBox(width: 6),
                            Text(
                              'PAUSED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatPeso(rule.amount, decimals: 0)} â€¢ '
                        '${rule.frequency.label} â€¢ ${rule.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next == null
                            ? 'Finished'
                            : 'Next: ${DateFormat('MMM d').format(next)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: paused ? AppColors.faint : AppColors.greenDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: rule.active,
                  activeThumbColor: _green,
                  onChanged: (v) => context
                      .read<ExpenseProvider>()
                      .setRecurringActive(rule, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final provider = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Expenses this rule already logged stay in your history.
    await provider.deleteRecurring(rule);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed "${rule.title}"'),
        backgroundColor: AppColors.tooltipBg,
        action: SnackBarAction(
          label: 'Undo',
          textColor: _green,
          onPressed: () => provider.restoreRecurring(rule),
        ),
      ),
    );
  }
}
