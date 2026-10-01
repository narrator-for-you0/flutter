import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';

class EditBudgetModal extends StatefulWidget {
  const EditBudgetModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

  // Tentative cycle settings being edited — only written to the provider on
  // Save, so switching types here to preview doesn't change anything live.
  late AllowanceCycleType _cycleType;
  late int _cycleWeekday; // 1 = Monday .. 7 = Sunday (matches DateTime.weekday)
  late DateTime _anchorPreview; // effective anchor date while editing
  late DateTime _selectedPeriodStart; // the period currently shown/edited

  static const primaryGreen = Color(0xFF00C853);
  static Color get darkText => AppColors.text;
  static Color get labelColor => AppColors.muted;

  final List<double> _suggestedBudgets = [4000, 6000, 8000];

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    _cycleType = provider.cycleType;
    _cycleWeekday = provider.cycleAnchor.weekday;
    _anchorPreview = provider.cycleAnchor;
    _selectedPeriodStart = provider.currentCycleStart(DateTime.now());

    final currentBudget = provider.getBudgetForCycle(DateTime.now());
    _amountController = TextEditingController(
      text: formatAmountInput(currentBudget, decimals: 0),
    );

    // Empty = automatic (budget / days in the cycle)
    final custom = provider.customDailyLimit;
    _dailyLimitController = TextEditingController(
      text: custom == null ? '' : formatAmountInput(custom, decimals: 0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  // Most recent date on/before [from] that falls on [weekday]. Used so
  // picking a weekday gives a concrete anchor date (needed for biweekly to
  // know which of the two weeks is "week 1").
  DateTime _mostRecentWeekday(DateTime from, int weekday) {
    final d = DateTime(from.year, from.month, from.day);
    final diff = (d.weekday - weekday) % 7;
    return d.subtract(Duration(days: diff));
  }

  void _refreshAmountField() {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final key = provider.budgetKeyFor(_cycleType, _selectedPeriodStart);
    _amountController.text = formatAmountInput(
      provider.budgetForCycleKey(key),
      decimals: 0,
    );
  }

  void _selectCycleType(AllowanceCycleType type) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    setState(() {
      _cycleType = type;
      if (type != AllowanceCycleType.monthly) {
        _anchorPreview = _mostRecentWeekday(DateTime.now(), _cycleWeekday);
      }
      _selectedPeriodStart = provider.cycleStartFor(
        _cycleType,
        _anchorPreview,
        DateTime.now(),
      );
      _refreshAmountField();
    });
  }

  void _selectWeekday(int weekday) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    setState(() {
      _cycleWeekday = weekday;
      _anchorPreview = _mostRecentWeekday(DateTime.now(), weekday);
      _selectedPeriodStart = provider.cycleStartFor(
        _cycleType,
        _anchorPreview,
        DateTime.now(),
      );
      _refreshAmountField();
    });
  }

  void _changePeriod(int delta) {
    DateTime newStart;
    switch (_cycleType) {
      case AllowanceCycleType.monthly:
        newStart = DateTime(
          _selectedPeriodStart.year,
          _selectedPeriodStart.month + delta,
          1,
        );
        break;
      case AllowanceCycleType.weekly:
        newStart = _selectedPeriodStart.add(Duration(days: 7 * delta));
        break;
      case AllowanceCycleType.biweekly:
        newStart = _selectedPeriodStart.add(Duration(days: 14 * delta));
        break;
    }
    setState(() {
      _selectedPeriodStart = newStart;
      _refreshAmountField();
    });
  }

  int get _cycleLengthPreview {
    switch (_cycleType) {
      case AllowanceCycleType.monthly:
        return DateUtils.getDaysInMonth(
          _selectedPeriodStart.year,
          _selectedPeriodStart.month,
        );
      case AllowanceCycleType.weekly:
        return 7;
      case AllowanceCycleType.biweekly:
        return 14;
    }
  }

  String get _periodLabel {
    switch (_cycleType) {
      case AllowanceCycleType.monthly:
        return DateFormat('MMMM yyyy').format(_selectedPeriodStart);
      case AllowanceCycleType.weekly:
        return 'Week of ${DateFormat('MMM d').format(_selectedPeriodStart)}';
      case AllowanceCycleType.biweekly:
        return '2 Weeks from ${DateFormat('MMM d').format(_selectedPeriodStart)}';
    }
  }

  String get _budgetFieldLabel {
    switch (_cycleType) {
      case AllowanceCycleType.monthly:
        return 'MONTHLY FOOD BUDGET (₱)';
      case AllowanceCycleType.weekly:
        return 'WEEKLY FOOD BUDGET (₱)';
      case AllowanceCycleType.biweekly:
        return 'BIWEEKLY FOOD BUDGET (₱)';
    }
  }

  void _save() {
    final value = double.tryParse(_amountController.text.trim());
    if (value != null && value > 0) {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      provider.setAllowanceCycle(
        _cycleType,
        anchor: _cycleType == AllowanceCycleType.monthly
            ? null
            : _anchorPreview,
      );
      provider.updateBudgetForCycle(value, _cycleType, _selectedPeriodStart);
      // Empty / invalid -> null -> automatic daily limit
      provider.setDailyLimit(
        double.tryParse(_dailyLimitController.text.trim()),
      );
      Navigator.pop(context);
    }
  }

  Widget _cycleTypeChip(AllowanceCycleType type, String label) {
    final isSelected = _cycleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectCycleType(type),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : darkText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentAmount = double.tryParse(_amountController.text) ?? 0;
    final autoDaily = _cycleLengthPreview > 0
        ? currentAmount / _cycleLengthPreview
        : 0.0;
    final showWeekdayPicker = _cycleType != AllowanceCycleType.monthly;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Budget',
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
                    icon: Icon(Icons.close, color: labelColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Allowance cycle picker
              Text(
                'ALLOWANCE CYCLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _cycleTypeChip(AllowanceCycleType.monthly, 'Monthly'),
                  _cycleTypeChip(AllowanceCycleType.weekly, 'Weekly'),
                  _cycleTypeChip(AllowanceCycleType.biweekly, 'Biweekly'),
                ],
              ),

              if (showWeekdayPicker) ...[
                const SizedBox(height: 12),
                Text(
                  'CYCLE STARTS ON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (i) {
                    final weekday = i + 1;
                    final isSelected = _cycleWeekday == weekday;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _selectWeekday(weekday),
                        child: Container(
                          margin: EdgeInsets.only(right: weekday == 7 ? 0 : 6),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryGreen : AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _weekdayLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : darkText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16),

              // Amount field
              Text(
                _budgetFieldLabel,
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
                        style: TextStyle(
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
              Text(
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
                          _amountController.text = formatAmountInput(
                            amount,
                            decimals: 0,
                          );
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryGreen : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          formatPeso(amount, decimals: 0),
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

              // Budget period (cycle-aware: a month, a week, or two weeks)
              Text(
                'BUDGET PERIOD',
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
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: labelColor),
                      onPressed: () => _changePeriod(-1),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: labelColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _periodLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: labelColor),
                      onPressed: () => _changePeriod(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Daily limit (optional override)
              Text(
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
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _dailyLimitController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    prefixText: '₱ ',
                    hintText:
                        'Auto: ${formatPeso(autoDaily, decimals: 0)} per day',
                    hintStyle: TextStyle(fontSize: 14, color: labelColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Leave empty to use your budget ÷ days in the cycle. You'll get a warning when a day goes over.",
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
