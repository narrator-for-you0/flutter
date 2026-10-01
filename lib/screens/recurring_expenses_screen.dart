import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/expense_category.dart';
import '../models/recurring_expense.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';
import 'recurring_expense_modal.dart';

/// Lists every recurring expense: pause/resume, tap to edit, swipe to delete.
class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFDC2626);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  String _statusText(RecurringExpense r) {
    if (!r.active) return 'Paused';
    final next = r.nextOccurrence(DateTime.now());
    if (next == null) return 'Ended';
    return 'Next: ${DateFormat('EEE, MMM d').format(next)}';
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Recurring expenses',
          style: TextStyle(color: _dark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _dark),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RecurringExpenseModal.show(context),
        backgroundColor: _green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add recurring',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final items = provider.recurringExpenses;
          final messenger = ScaffoldMessenger.of(context);

          if (items.isEmpty) return _emptyState();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Logged automatically when due. If you skip a few days, the missed '
                'ones are filled in with their original dates the next time you open the app.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              ...items.map((r) => _dismissibleRow(context, provider, messenger, r)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 44, color: AppColors.faint),
            const SizedBox(height: 12),
            Text(
              'No recurring expenses yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              'Add things that repeat, like weekly load, printing, or a daily '
              'jeepney fare, and they log themselves.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dismissibleRow(
    BuildContext context,
    ExpenseProvider provider,
    ScaffoldMessengerState messenger,
    RecurringExpense r,
  ) {
    return Dismissible(
      key: ValueKey('recurring_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.redSoft2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: _red),
      ),
      onDismissed: (_) {
        provider.deleteRecurring(r);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted ${r.title}. Past expenses stay in your history.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => provider.restoreRecurring(r),
            ),
          ),
        );
      },
      child: _row(context, provider, r),
    );
  }

  Widget _row(BuildContext context, ExpenseProvider provider, RecurringExpense r) {
    final type = CategoryData.typeOfCategory(r.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => RecurringExpenseModal.show(context, existing: r),
          child: Opacity(
            opacity: r.active ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: type.softBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      CategoryData.emojiFor(r.category),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${r.amount.toStringAsFixed(r.amount % 1 == 0 ? 0 : 2)} • ${r.frequency.label} • ${r.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusText(r),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: r.active ? _green : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: r.active,
                    activeThumbColor: _green,
                    onChanged: (v) => provider.setRecurringActive(r, v),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}