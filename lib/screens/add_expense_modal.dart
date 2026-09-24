import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class AddExpenseModal extends StatefulWidget {
  const AddExpenseModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddExpenseModal(),
    );
  }

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _foodNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

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

  final List<Map<String, String>> categories = [
    {'icon': '🍳', 'label': 'Breakfast'},
    {'icon': '🍜', 'label': 'Lunch'},
    {'icon': '🍽️', 'label': 'Dinner'},
    {'icon': '🍪', 'label': 'Snacks'},
    {'icon': '🥤', 'label': 'Drinks'},
    {'icon': '🍔', 'label': 'Fast Food'},
    {'icon': '☕', 'label': 'Coffee'},
    {'icon': '🛒', 'label': 'Groceries'},
    {'icon': '🍴', 'label': 'Other'},
  ];

  final List<String> paymentMethods = ['Cash', 'GCash', 'Card'];

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

  void _saveExpense() {
    final title = _foodNameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    // Validation
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid food name and amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
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
      // Pass notes if defined in your Expense model:
      // notes: _notesController.text.trim(),
    );

    // Commit to Provider
    Provider.of<ExpenseProvider>(context, listen: false).addExpense(newExpense);

    // Close Modal & Display Feedback
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $title (₱${amount.toStringAsFixed(2)})'),
        backgroundColor: primaryGreen,
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
                const Text(
                  'Add Expense',
                  style: TextStyle(
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

            // FOOD NAME SECTION
            _buildSectionLabel('FOOD NAME'),
            TextField(
              controller: _foodNameController,
              decoration: InputDecoration(
                hintText: 'e.g., Pepperoni Pizza, Milk Tea',
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
              children: quickFoodSuggestions.map((item) {
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
            _buildSectionLabel('CATEGORY'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat['label'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = cat['label']!;
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
                        Text(cat['icon']!, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? primaryGreen : textColor,
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
                label: const Text(
                  'Save Expense',
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