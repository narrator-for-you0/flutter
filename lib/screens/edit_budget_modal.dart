import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';

class EditBudgetModal extends StatefulWidget {
  const EditBudgetModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EditBudgetModal(),
    );
  }

  @override
  State<EditBudgetModal> createState() => _EditBudgetModalState();
}

class _EditBudgetModalState extends State<EditBudgetModal> {
  late final TextEditingController _amountController;
  late final TextEditingController _dailyLimitController;
  late DateTime _selectedMonth;

  static const primaryGreen = Color(0xFF00C853);
  static const darkText = Color(0xFF1E293B);
  static const labelColor = Color(0xFF64748B);

  final List<double> _suggestedBudgets = [4000, 6000, 8000];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    final currentBudget = Provider.of<ExpenseProvider>(context, listen: false)
        .getBudgetForMonth(_selectedMonth);
    _amountController =
        TextEditingController(text: currentBudget.toStringAsFixed(0));

    // Empty = automatic (budget / days in month)
    final custom =
        Provider.of<ExpenseProvider>(context, listen: false).customDailyLimit;
    _dailyLimitController =
        TextEditingController(text: custom?.toStringAsFixed(0) ?? '');
  }

  void _changeMonth(int delta) {
    final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    final budgetForMonth = Provider.of<ExpenseProvider>(context, listen: false)
        .getBudgetForMonth(newMonth);
    setState(() {
      _selectedMonth = newMonth;
      _amountController.text = budgetForMonth.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_amountController.text.trim());
    if (value != null && value > 0) {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      provider.updateBudget(value, month: _selectedMonth);
      // Empty / invalid -> null -> automatic daily limit
      provider.setDailyLimit(double.tryParse(_dailyLimitController.text.trim()));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentAmount = double.tryParse(_amountController.text) ?? 0;
    final autoDaily = currentAmount /
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: primaryGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Edit Monthly Budget',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Set your student food allowance',
                        style: TextStyle(fontSize: 12, color: labelColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: labelColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount field
            const Text(
              'MONTHLY FOOD BUDGET (₱)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: primaryGreen, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Text(
                    '₱',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: darkText,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Suggested budgets
            const Text(
              'Suggested Student Budgets:',
              style: TextStyle(fontSize: 12, color: labelColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: _suggestedBudgets.map((amount) {
                final isSelected = currentAmount == amount;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _amountController.text = amount.toStringAsFixed(0);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₱${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : darkText,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Budget month (display only for now — app tracks a single active budget)
            const Text(
              'BUDGET MONTH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: labelColor),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: labelColor),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(fontSize: 14, color: darkText, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: labelColor),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily limit (optional override)
            const Text(
              'DAILY LIMIT (₱) — OPTIONAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: labelColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _dailyLimitController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  prefixText: '₱ ',
                  hintText: 'Auto: ₱${autoDaily.toStringAsFixed(0)} per day',
                  hintStyle: const TextStyle(fontSize: 14, color: labelColor),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Leave empty to use your budget ÷ days in the month. You'll get a warning when a day goes over.",
              style: TextStyle(fontSize: 11, color: labelColor, height: 1.3),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: const Text(
                  'Save Budget',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
