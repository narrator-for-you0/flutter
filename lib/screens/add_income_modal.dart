import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/income.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';

/// Bottom sheet for logging money coming in (allowance, gift, etc).
class AddIncomeModal extends StatefulWidget {
  /// Pre-fill the date (e.g. from the calendar's "+ Add for Sep 20").
  final DateTime? initialDate;

  /// When set, the sheet edits this income entry instead of adding a new one.
  final Income? existing;

  const AddIncomeModal({super.key, this.initialDate, this.existing});

  /// Resolves to the date of the income that was saved, or null if the
  /// sheet was dismissed without saving.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    Income? existing,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIncomeModal(initialDate: initialDate, existing: existing),
    );
  }

  @override
  State<AddIncomeModal> createState() => _AddIncomeModalState();
}

class _AddIncomeModalState extends State<AddIncomeModal> {
  static const _green = Color(0xFF00C853);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  final List<double> _suggestedAmounts = [500, 1000, 2000];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.amount.toStringAsFixed(0);
      _noteController.text = existing.note;
      _date = DateTime(existing.date.year, existing.date.month, existing.date.day);
    } else {
      final d = widget.initialDate ?? DateTime.now();
      _date = DateTime(d.year, d.month, d.day);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    _saving = true;

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final note = _noteController.text.trim();

    if (_isEditing) {
      final original = widget.existing!;
      await provider.updateIncome(
        original,
        original.copyWith(amount: amount, note: note, date: _date),
      );
    } else {
      await provider.addIncome(Income(amount: amount, note: note, date: _date));
    }
    if (!mounted) return;
    Navigator.pop(context, _date);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_card, color: _green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Income' : 'Add Income',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _dark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEditing
                              ? 'Update this income entry'
                              : 'Allowance, gift, or anything else coming in',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close, color: _muted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'AMOUNT (₱)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _green, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Text('₱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _green)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _dark),
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
              const SizedBox(height: 12),

              Row(
                children: _suggestedAmounts.map((amount) {
                  final isSelected = double.tryParse(_amountController.text) == amount;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _amountController.text = amount.toStringAsFixed(0)),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? _green : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₱${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : _dark,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Text(
                'NOTE (OPTIONAL)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _noteController,
                  style: TextStyle(fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'e.g. Allowance from Mom',
                    hintStyle: TextStyle(fontSize: 13, color: _muted),
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'DATE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_date),
                        style: TextStyle(fontSize: 14, color: _dark, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Save Income',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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