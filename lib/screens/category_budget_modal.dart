import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';

/// Bottom sheet to cap spending per major type (Food, Transportation, Other)
/// and/or per subcategory (Coffee, Jeepney, ...). Limits apply to each budget
/// period; leave a field empty for no limit.
class CategoryBudgetModal extends StatefulWidget {
  const CategoryBudgetModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategoryBudgetModal(),
    );
  }

  @override
  State<CategoryBudgetModal> createState() => _CategoryBudgetModalState();
}

class _CategoryBudgetModalState extends State<CategoryBudgetModal> {
  static const _green = Color(0xFF00C853);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  // One text field per type and per subcategory, keyed like the provider's map.
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    final limits = Provider.of<ExpenseProvider>(context, listen: false).categoryBudgets;

    String textFor(String key) {
      final v = limits[key];
      return v == null ? '' : v.toStringAsFixed(0);
    }

    for (final t in CategoryData.types) {
      _controllers[typeBudgetKey(t.name)] =
          TextEditingController(text: textFor(typeBudgetKey(t.name)));
      for (final s in t.subCategories) {
        final key = subBudgetKey(s.label);
        _controllers[key] = TextEditingController(text: textFor(key));
        // Open a type's list right away if one of its subcategories has a limit.
        if (limits.containsKey(key)) _expanded.add(t.name);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = <String, double?>{};
    _controllers.forEach((key, controller) {
      final v = double.tryParse(controller.text.trim());
      values[key] = (v != null && v > 0) ? v : null;
    });
    Provider.of<ExpenseProvider>(context, listen: false).setCategoryBudgets(values);
    Navigator.pop(context);
  }

  Widget _amountField(TextEditingController controller, {double width = 104}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dark),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.fill,
          prefixText: '₱ ',
          prefixStyle: TextStyle(fontSize: 13, color: _muted),
          hintText: 'None',
          hintStyle: TextStyle(fontSize: 13, color: _muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _typeBlock(ExpenseType t) {
    final open = _expanded.contains(t.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Text(t.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      if (open) {
                        _expanded.remove(t.name);
                      } else {
                        _expanded.add(t.name);
                      }
                    }),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _dark,
                            ),
                          ),
                        ),
                        Icon(
                          open ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _amountField(_controllers[typeBudgetKey(t.name)]!),
              ],
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: t.subCategories.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(fontSize: 13, color: _dark),
                          ),
                        ),
                        _amountField(_controllers[subBudgetKey(s.label)]!, width: 96),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
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
                    child: const Icon(Icons.pie_chart_outline, color: _green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category limits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'The most you want to spend per period. Leave empty for no limit.',
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
              const SizedBox(height: 16),
              ...CategoryData.types.map(_typeBlock),
              const SizedBox(height: 4),
              Text(
                'Tap a type to set limits for individual categories. Expenses paid '
                'from savings never count toward a limit.',
                style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text(
                    'Save Limits',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
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