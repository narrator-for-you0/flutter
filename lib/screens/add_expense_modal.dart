import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../widgets/daily_limit_widgets.dart';

class AddExpenseModal extends StatefulWidget {
  /// Pre-fill the date (e.g. from the calendar's "+ Add for Sep 20").
  final DateTime? initialDate;

  /// When set, the sheet edits this expense instead of adding a new one.
  final Expense? existing;

  /// Start with "Pay from savings" switched on (used by the Savings view).
  final bool startFromSavings;

  const AddExpenseModal({
    super.key,
    this.initialDate,
    this.existing,
    this.startFromSavings = false,
  });

  /// Resolves to the date of the expense that was saved, or null if the
  /// sheet was dismissed without saving.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    Expense? existing,
    bool startFromSavings = false,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddExpenseModal(
        initialDate: initialDate,
        existing: existing,
        startFromSavings: startFromSavings,
      ),
    );
  }

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _foodNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseType selectedType = CategoryData.food;
  bool _saving = false;
  String selectedCategory = 'Lunch';
  String selectedPayment = 'GCash';
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  // Color Palette
  static const primaryGreen = Color(0xFF00C853);
  static const inputBgColor = Color(0xFFF8FAFC);
  static const chipBgColor = Color(0xFFF1F5F9);
  static const labelColor = Color(0xFF94A3B8);
  static const textColor = Color(0xFF1E293B);

  final List<String> quickFoodSuggestions = [
    'Softdrinks',
    'Milk Tea',
    'Pastil',
    'Iced Coffee',
    'Egg & Rice'
  ];


  final List<String> paymentMethods = ['Cash', 'GCash', 'Card'];

  bool get _isEditing => widget.existing != null;

  // "Pay from savings": doesn't count against the budget or daily limit.
  bool _fromSavings = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fromSavings = e?.fromSavings ?? widget.startFromSavings;
    if (e != null) {
      _foodNameController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      selectedType = CategoryData.typeOfCategory(e.category);
      selectedCategory = e.category;
      if (paymentMethods.contains(e.paymentMethod)) {
        selectedPayment = e.paymentMethod;
      }
      selectedDate = e.date;
      selectedTime = TimeOfDay.fromDateTime(e.date);
    } else if (widget.initialDate != null) {
      final d = widget.initialDate!;
      selectedDate = DateTime(d.year, d.month, d.day);
    }
  }

  // Name-field text + quick suggestions change with the selected type
  String get _nameLabel {
    switch (selectedType.name) {
      case 'Transportation':
        return 'TRIP / DESCRIPTION';
      case 'Other':
        return 'DESCRIPTION';
      default:
        return 'FOOD NAME';
    }
  }

  String get _nameHint {
    switch (selectedType.name) {
      case 'Transportation':
        return 'e.g., Jeepney to campus, Grab home';
      case 'Other':
        return 'e.g., Bond paper, Load, Notebook';
      default:
        return 'e.g., Pepperoni Pizza, Milk Tea';
    }
  }

  List<String> get _suggestions {
    switch (selectedType.name) {
      case 'Transportation':
        return ['Jeepney fare', 'Tricycle', 'Habal-habal', 'Grab', 'Gas'];
      case 'Other':
        return ['Bond paper', 'Printing', 'Load', 'Notebook'];
      default:
        return quickFoodSuggestions;
    }
  }

  Widget _buildTypeSelector() {
    return Row(
      children: CategoryData.types.map((t) {
        final isSelected = selectedType.name == t.name;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                selectedType = t;
                selectedCategory = t.subCategories.first.label;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? t.softColor : inputBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? t.color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(t.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? t.color : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addQuickAmount(double value) {
    double current = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _amountController.text = (current + value).toStringAsFixed(2);
    });
  }

  void _clearAmount() {
    setState(() {
      _amountController.clear();
    });
  }

  Future<void> _saveExpense() async {
    final title = _foodNameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    // Validation
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid name and amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Can't spend more from savings than you have
    if (_fromSavings) {
      final existing = widget.existing;
      var available = Provider.of<ExpenseProvider>(context, listen: false).savingsBalance;
      if (existing != null && existing.fromSavings) available += existing.amount;
      if (amount > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough savings — ₱${available.toStringAsFixed(2)} available',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Combine Date and Time
    final fullDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Instantiate Expense Model
    final newExpense = Expense(
      title: title,
      amount: amount,
      category: selectedCategory,
      date: fullDateTime,
      paymentMethod: selectedPayment,
      fromSavings: _fromSavings,
      // Pass notes if defined in your Expense model:
      // notes: _notesController.text.trim(),
    );

    if (_saving) return;
    _saving = true;

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    // Commit to Provider (edit keeps the original id)
    final LimitCheck check;
    if (_isEditing) {
      final original = widget.existing!;
      check = await provider.updateExpense(
        original,
        Expense(
          id: original.id,
          title: title,
          amount: amount,
          category: selectedCategory,
          date: fullDateTime,
          paymentMethod: selectedPayment,
          fromSavings: _fromSavings,
        ),
      );
    } else {
      check = await provider.addExpense(newExpense);
    }
    if (!mounted) return;

    // Daily-limit pop-up (shown over the sheet if this expense crossed the limit)
    await DailyLimitAlert.handle(context, check);
    if (!mounted) return;

    // Close Modal (returning the saved date) & Display Feedback
    Navigator.pop(context, fullDateTime);
    final overNow = !_fromSavings && check.isOver && !check.crossed;
    final verb = _isEditing ? 'Updated' : 'Added';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          overNow
              ? '$verb $title (₱${amount.toStringAsFixed(2)}) • ₱${check.overBy.toStringAsFixed(0)} over daily limit'
              : '$verb $title (₱${amount.toStringAsFixed(2)})${_fromSavings ? ' from savings' : ''}',
        ),
        backgroundColor: overNow ? Colors.redAccent : primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  _isEditing ? 'Edit Expense' : 'Add Expense',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: labelColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TYPE SECTION
            _buildSectionLabel('TYPE'),
            _buildTypeSelector(),
            const SizedBox(height: 16),

            // NAME SECTION
            _buildSectionLabel(_nameLabel),
            TextField(
              controller: _foodNameController,
              decoration: InputDecoration(
                hintText: _nameHint,
                hintStyle: const TextStyle(color: labelColor, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Food Suggestions Wrap
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions.map((item) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _foodNameController.text = item;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: chipBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        color: labelColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // AMOUNT SECTION
            _buildSectionLabel('AMOUNT (₱)'),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                prefixText: '₱ ',
                prefixStyle: const TextStyle(fontSize: 18, color: labelColor, fontWeight: FontWeight.bold),
                hintText: '0.00',
                hintStyle: const TextStyle(color: labelColor, fontSize: 18),
                filled: true,
                fillColor: inputBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Add Amounts
            Row(
              children: [
                const Text('Quick add: ', style: TextStyle(color: labelColor, fontSize: 11)),
                const SizedBox(width: 4),
                _buildQuickAddButton('+₱20', 20),
                const SizedBox(width: 6),
                _buildQuickAddButton('+₱50', 50),
                const SizedBox(width: 6),
                _buildQuickAddButton('+₱100', 100),
                const Spacer(),
                GestureDetector(
                  onTap: _clearAmount,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: labelColor, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CATEGORY GRID SECTION
            _buildSectionLabel('CATEGORY (${selectedType.name.toUpperCase()})'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedType.subCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final cat = selectedType.subCategories[index];
                final isSelected = selectedCategory == cat.label;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = cat.label;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : inputBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primaryGreen : Colors.transparent,
                        width: isSelected ? 1.5 : 0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? primaryGreen : textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // PAYMENT & DATE
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('PAYMENT'),
                      Row(
                        children: paymentMethods.map((method) {
                          final isSelected = selectedPayment == method;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => selectedPayment = method),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : inputBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? primaryGreen : Colors.transparent,
                                    width: isSelected ? 1.5 : 0,
                                  ),
                                ),
                                child: Text(
                                  method,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? primaryGreen : textColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('DATE'),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: inputBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MM/dd/yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 12, color: textColor),
                              ),
                              const Icon(Icons.calendar_today_outlined, size: 14, color: labelColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // PAY FROM SAVINGS (only offered when there are savings to use)
            Builder(
              builder: (context) {
                final provider = Provider.of<ExpenseProvider>(context);
                final existing = widget.existing;
                var available = provider.savingsBalance;
                if (existing != null && existing.fromSavings) available += existing.amount;
                if (available <= 0 && !_fromSavings) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _fromSavings ? const Color(0xFFDCFCE7) : inputBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fromSavings ? primaryGreen : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_outlined, size: 20, color: primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pay from savings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '₱${available.toStringAsFixed(2)} available • won\'t count against your budget',
                              style: const TextStyle(fontSize: 11, color: labelColor),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _fromSavings,
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        trackColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              states.contains(WidgetState.selected) ? primaryGreen : null,
                        ),
                        onChanged: (v) => setState(() => _fromSavings = v),
                      ),
                    ],
                  ),
                );
              },
            ),

            // TIME & NOTES
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('TIME'),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) setState(() => selectedTime = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: inputBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontSize: 12, color: textColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('NOTES'),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: 'Optional note',
                          hintStyle: const TextStyle(color: labelColor, fontSize: 12),
                          filled: true,
                          fillColor: inputBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check, color: Colors.white, size: 20),
                label: Text(
                  _isEditing ? 'Save Changes' : 'Save Expense',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(String text, double amount) {
    return GestureDetector(
      onTap: () => _addQuickAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chipBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}