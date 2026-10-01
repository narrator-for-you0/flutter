import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';

class ManageQuickAddModal extends StatefulWidget {
  const ManageQuickAddModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageQuickAddModal(),
    );
  }

  @override
  State<ManageQuickAddModal> createState() => _ManageQuickAddModalState();
}

class _ManageQuickAddModalState extends State<ManageQuickAddModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedEmoji = '🍜';
  ExpenseType _selectedType = CategoryData.food;
  String _selectedCategory = 'Lunch';

  final List<String> _emojis = ['🍜', '🍳', '🧋', '☕', '🍔', '🍕', '🍰', '🍱', '🚌', '🛺', '📚'];

  Widget _buildTypeChips() {
    return Row(
      children: CategoryData.types.map((t) {
        final isSelected = _selectedType.name == t.name;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isSelected) return;
              setState(() {
                _selectedType = t;
                _selectedCategory = t.subCategories.first.label;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? t.softBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? t.color : AppColors.greyBorder,
                ),
              ),
              child: Text(
                '${t.emoji} ${t.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? t.color : AppColors.black87,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final provider = Provider.of<ExpenseProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
       child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customize Quick Add',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // List of current items
          ...provider.quickAddItems.map((item) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(item.emoji, style: const TextStyle(fontSize: 18)),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('₱${item.amount.toStringAsFixed(0)} • ${item.category}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.removeQuickAddItem(item.id),
              ),
            );
          }),

          const Divider(height: 24),
          const Text(
            'Add New Shortcut',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Emoji Selector
          Wrap(
            runSpacing: 8,
            children: _emojis.map((emoji) {
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = emoji),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedEmoji == emoji
                        ? AppColors.greenSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedEmoji == emoji
                          ? const Color(0xFF00C853)
                          : AppColors.greyBorder,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 16)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Title & Amount Form
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              hintText: 'e.g. Coffee',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (₱)',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),

          _buildTypeChips(),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            // new key => rebuilds with the right initialValue when the type changes
            key: ValueKey(_selectedType.name),
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _selectedType.subCategories.map((sub) {
              return DropdownMenuItem(
                value: sub.label,
                child: Text('${sub.emoji}  ${sub.label}'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCategory = val);
              }
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                
              ),
              onPressed: () {
                final title = _titleController.text.trim();
                final amount = double.tryParse(_amountController.text) ?? 0;
                if (title.isNotEmpty && amount > 0) {
                  provider.addQuickAddItem(title, amount, _selectedEmoji, _selectedCategory);
                  _titleController.clear();
                  _amountController.clear();
                }
              },
              child: const Text('Add Shortcut', style: TextStyle( color: Colors.white)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}