import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_providers.dart';
import 'reminder_settings_modal.dart';
import 'category_budget_modal.dart';
import 'recurring_expenses_screen.dart';
import '../themes/app_colors.dart';

/// App-wide settings: appearance (theme) for now, with room for more
/// (data export, category budgets, etc.) as later phases land.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _green = Color(0xFF00C853);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final themeProvider = context.watch<ThemeProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(color: _dark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _dark),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('APPEARANCE'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                _themeOption(
                  context,
                  mode: ThemeMode.light,
                  current: themeProvider.mode,
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  onTap: () => themeProvider.setMode(ThemeMode.light),
                ),
                Divider(height: 1, color: AppColors.border),
                _themeOption(
                  context,
                  mode: ThemeMode.dark,
                  current: themeProvider.mode,
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  onTap: () => themeProvider.setMode(ThemeMode.dark),
                ),
                Divider(height: 1, color: AppColors.border),
                _themeOption(
                  context,
                  mode: ThemeMode.system,
                  current: themeProvider.mode,
                  icon: Icons.brightness_auto_outlined,
                  label: 'Match device setting',
                  onTap: () => themeProvider.setMode(ThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel('BUDGET'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Icon(Icons.pie_chart_outline, color: _muted),
                  title: Text(
                    'Category limits',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
                  ),
                  subtitle: Text(
                    expenseProvider.categoryBudgets.isEmpty
                        ? 'No limits set'
                        : '${expenseProvider.categoryBudgets.length} set',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  trailing: Icon(Icons.chevron_right, color: _muted),
                  onTap: () => CategoryBudgetModal.show(context),
                ),
                Divider(height: 1, color: AppColors.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Icon(Icons.repeat, color: _muted),
                  title: Text(
                    'Recurring expenses',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
                  ),
                  subtitle: Text(
                    expenseProvider.recurringExpenses.isEmpty
                        ? 'None yet'
                        : '${expenseProvider.recurringExpenses.where((r) => r.active).length} active',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  trailing: Icon(Icons.chevron_right, color: _muted),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecurringExpensesScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel('NOTIFICATIONS'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Icon(
                    expenseProvider.reminderEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_none_outlined,
                    color: expenseProvider.reminderEnabled ? _green : _muted,
                  ),
                  title: Text(
                    'Daily reminder',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
                  ),
                  subtitle: Text(
                    expenseProvider.reminderEnabled
                        ? 'On • ${expenseProvider.reminderTime.format(context)}'
                        : 'Off',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  trailing: Icon(Icons.chevron_right, color: _muted),
                  onTap: () => ReminderSettingsModal.show(context),
                ),
                Divider(height: 1, color: AppColors.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Icon(
                    Icons.flag_outlined,
                    color: expenseProvider.cycleSummaryEnabled ? _green : _muted,
                  ),
                  title: Text(
                    'Period summary',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
                  ),
                  subtitle: Text(
                    'When a budget period ends, tell me how it went',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  trailing: Switch(
                    value: expenseProvider.cycleSummaryEnabled,
                    activeThumbColor: _green,
                    onChanged: (v) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await context.read<ExpenseProvider>().setCycleSummaryEnabled(v);
                      if (v && !ok) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are blocked for this app. Allow them in your device settings, then turn this on again.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 0.5),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required ThemeMode mode,
    required ThemeMode current,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final selected = mode == current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _green : _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? _dark : _muted,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle, size: 20, color: _green),
          ],
        ),
      ),
    );
  }
}