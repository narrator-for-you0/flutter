import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/expense_category.dart';
import '../models/recurring_expense.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';

/// Bottom sheet to create or edit a recurring expense.
class RecurringExpenseModal extends StatefulWidget {
  /// When set, the sheet edits this entry instead of creating a new one.
  final RecurringExpense? existing;

  const RecurringExpenseModal({super.key, this.existing});

  static Future<void> show(BuildContext context, {RecurringExpense? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecurringExpenseModal(existing: existing),
    );
  }

  @override
  State<RecurringExpenseModal> createState() => _RecurringExpenseModalState();
}

class _RecurringExpenseModalState extends State<RecurringExpenseModal> {
  static const _green = Color(0xFF00C853);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;
  static const _payments = ['Cash', 'GCash', 'Card'];

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseType _type = CategoryData.other;
  String _category = 'Load / Data';
  String _payment = 'Cash';
  RecurringFrequency _frequency = RecurringFrequency.weekly;
  late DateTime _start;
  DateTime? _end;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      // Show cents only when this amount actually has any, so a whole-peso
      // amount doesn't come back as "100.00" in the field.
      _amountController.text = formatAmountInput(
        e.amount,
        decimals: e.amount % 1 == 0 ? 0 : 2,
      );
      _type = CategoryData.typeOfCategory(e.category);
      _category = e.category;
      if (_payments.contains(e.paymentMethod)) _payment = e.paymentMethod;
      _frequency = e.frequency;
      _start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      _end = e.endDate;
    } else {
      final now = DateTime.now();
      _start = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) {
      _snack('Please enter a valid name and amount');
      return;
    }
    if (_end != null && _end!.isBefore(_start)) {
      _snack('The end date has to be on or after the start date');
      return;
    }

    _saving = true;
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final existing = widget.existing;

    final entry = RecurringExpense(
      id: existing?.id,
      title: title,
      amount: amount,
      category: _category,
      paymentMethod: _payment,
      frequency: _frequency,
      startDate: _start,
      endDate: _end,
      lastGenerated: existing?.lastGenerated,
      active: existing?.active ?? true,
    );

    final int? created = _isEditing
        ? await provider.updateRecurring(entry)
        : await provider.addRecurring(entry);
    if (!mounted) return;

    if (created == null) {
      _saving = false;
      _snack(
        'Could not save: ${provider.lastRecurringError ?? 'unknown error'}',
      );
      return;
    }

    Navigator.pop(context);
    final extra = created > 0
        ? ' • $created ${created == 1 ? 'expense' : 'expenses'} logged now'
        : '';
    messenger.showSnackBar(
      SnackBar(
        content: Text('${_isEditing ? 'Updated' : 'Added'} $title$extra'),
        backgroundColor: _green,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color accent = _green,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? accent : _dark,
          ),
        ),
      ),
    );
  }

  Widget _dateRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: _dark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _textBox(
    TextEditingController c,
    String hint, {
    TextInputType? type,
    String? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: c,
        keyboardType: type,
        style: TextStyle(fontSize: 14, color: _dark),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixText: prefix,
          prefixStyle: TextStyle(fontSize: 14, color: _muted),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: _muted),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    child: const Icon(Icons.repeat, color: _green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? 'Edit recurring expense'
                              : 'New recurring expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Logged for you automatically on schedule',
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

              _label('NAME'),
              _textBox(_titleController, 'e.g. Weekly load'),
              const SizedBox(height: 16),

              _label('AMOUNT (₱)'),
              _textBox(
                _amountController,
                '0',
                type: const TextInputType.numberWithOptions(decimal: true),
                prefix: '₱ ',
              ),
              const SizedBox(height: 16),

              _label('CATEGORY'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryData.types.map((t) {
                  return _chip(
                    label: '${t.emoji} ${t.name}',
                    selected: _type.name == t.name,
                    accent: t.color,
                    onTap: () => setState(() {
                      if (_type.name == t.name) return;
                      _type = t;
                      _category = t.subCategories.first.label;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _type.subCategories.map((s) {
                  return _chip(
                    label: '${s.emoji} ${s.label}',
                    selected: _category == s.label,
                    accent: s.color,
                    onTap: () => setState(() => _category = s.label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _label('REPEATS'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecurringFrequency.values.map((f) {
                  return _chip(
                    label: f.label,
                    selected: _frequency == f,
                    onTap: () => setState(() => _frequency = f),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _label('PAID WITH'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _payments.map((p) {
                  return _chip(
                    label: p,
                    selected: _payment == p,
                    onTap: () => setState(() => _payment = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              _label('STARTS'),
              _dateRow(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('EEEE, MMMM d, yyyy').format(_start),
                onTap: _pickStart,
              ),
              const SizedBox(height: 16),

              _label('ENDS (OPTIONAL)'),
              _dateRow(
                icon: Icons.event_busy_outlined,
                text: _end == null
                    ? 'Never'
                    : DateFormat('EEEE, MMMM d, yyyy').format(_end!),
                onTap: _pickEnd,
                trailing: _end == null
                    ? null
                    : GestureDetector(
                        onTap: () => setState(() => _end = null),
                        child: Icon(Icons.close, size: 18, color: _muted),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'If the start date is in the past, the earlier ones are logged right away, '
                'each on its own date.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Save Recurring Expense',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
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
