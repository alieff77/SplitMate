import 'package:flutter/material.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/bill_model.dart';

// Mutable item used only within editing UI
class _EditableItem {
  String id;
  String description;
  double amount;
  List<String> assignedToUserIds;

  _EditableItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.assignedToUserIds,
  });

  factory _EditableItem.from(BillItem item) => _EditableItem(
        id: item.id,
        description: item.description,
        amount: item.amount,
        assignedToUserIds: List.from(item.assignedToUserIds),
      );

  BillItem toBillItem() => BillItem(
        id: id,
        description: description,
        amount: amount,
        assignedToUserIds: List.from(assignedToUserIds),
      );
}

// ─── Main Card ────────────────────────────────────────────────────────────────

class BillDraftCard extends StatefulWidget {
  final BillDraft draft;
  final Map<String, String> memberNames;
  final Function(BillDraft) onConfirm;
  final VoidCallback onDiscard;
  final bool isLoading;

  const BillDraftCard({
    super.key,
    required this.draft,
    required this.memberNames,
    required this.onConfirm,
    required this.onDiscard,
    this.isLoading = false,
  });

  @override
  State<BillDraftCard> createState() => _BillDraftCardState();
}

class _BillDraftCardState extends State<BillDraftCard> {
  late String _title;
  late String _paidByUserId;
  late double _taxAmount;
  late double _serviceAmount;
  late List<_EditableItem> _items;
  DateTime? _customDate;

  @override
  void initState() {
    super.initState();
    _title = widget.draft.title;
    _paidByUserId = widget.draft.paidByUserId;
    _taxAmount = widget.draft.taxAmount;
    _serviceAmount = widget.draft.serviceChargeAmount;
    _items = widget.draft.items.map(_EditableItem.from).toList();
    _customDate = widget.draft.date;
  }

  // Calculate subtotal from all items
  double get _subtotal =>
      _items.fold(0.0, (s, item) => s + item.amount);

  // Calculate grand total including tax and service charge
  double get _total =>
      double.parse((_subtotal + _taxAmount + _serviceAmount).toStringAsFixed(2));

  // Compute per-user share amounts proportional to their items
  List<BillShare> _computeShares() {
    final Map<String, double> userSubtotals = {};
    for (final item in _items) {
      if (item.assignedToUserIds.isEmpty) continue;
      final per = item.amount / item.assignedToUserIds.length;
      for (final uid in item.assignedToUserIds) {
        userSubtotals[uid] = (userSubtotals[uid] ?? 0) + per;
      }
    }
    final sub = _subtotal;
    return userSubtotals.entries.map((e) {
      final prop = sub > 0 ? e.value / sub : 0.0;
      final uTax = double.parse((_taxAmount * prop).toStringAsFixed(2));
      final uSvc = double.parse((_serviceAmount * prop).toStringAsFixed(2));
      return BillShare(
        userId: e.key,
        amountOwed:
            double.parse((e.value + uTax + uSvc).toStringAsFixed(2)),
        isPaid: false,
        paidAt: null,
        markedPaidByUserId: null,
        confirmedByPayer: false,
      );
    }).toList();
  }

  // Build BillDraft from current editable state
  BillDraft _buildDraft() => BillDraft(
        title: _title,
        totalAmount: _total,
        subtotal: _subtotal,
        taxAmount: _taxAmount,
        serviceChargeAmount: _serviceAmount,
        paidByUserId: _paidByUserId,
        notes: widget.draft.notes,
        items: _items.map((e) => e.toBillItem()).toList(),
        shares: _computeShares(),
        date: _customDate,
      );

  // Open full-screen edit page for this draft
  void _openEditPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditBillPage(
          title: _title,
          paidByUserId: _paidByUserId,
          items: _items
              .map((e) => _EditableItem(
                    id: e.id,
                    description: e.description,
                    amount: e.amount,
                    assignedToUserIds: List.from(e.assignedToUserIds),
                  ))
              .toList(),
          memberNames: widget.memberNames,
          taxAmount: _taxAmount,
          serviceAmount: _serviceAmount,
          initialDate: _customDate,
          onSave: (title, paidByUserId, items, tax, svc, date) {
            setState(() {
              _title = title;
              _paidByUserId = paidByUserId;
              _items = items;
              _taxAmount = tax;
              _serviceAmount = svc;
              _customDate = date;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shares = _computeShares();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(77), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(13),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(_total),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _openEditPage,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Paid by
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              'Paid by: ${widget.memberNames[_paidByUserId] ?? _paidByUserId}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              children: _items.map((item) {
                final assigned = item.assignedToUserIds
                    .map((id) => widget.memberNames[id] ?? id)
                    .join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• ${item.description}${assigned.isNotEmpty ? ' ($assigned)' : ''}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(item.amount),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Tax / service charge
          if (_taxAmount > 0 || _serviceAmount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax + Service Charge',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    CurrencyFormatter.format(_taxAmount + _serviceAmount),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          const Divider(height: 20, indent: 14, endIndent: 14),

          // Shares
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: shares.map((share) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.memberNames[share.userId] ?? share.userId,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                      Text(
                        CurrencyFormatter.format(share.amountOwed),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.isLoading ? null : widget.onDiscard,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.isLoading
                        ? null
                        : () => widget.onConfirm(_buildDraft()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Bill'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full-Screen Edit Page ────────────────────────────────────────────────────

class _EditBillPage extends StatefulWidget {
  final String title;
  final String paidByUserId;
  final List<_EditableItem> items;
  final Map<String, String> memberNames;
  final double taxAmount;
  final double serviceAmount;
  final DateTime? initialDate;
  final Function(
    String title,
    String paidByUserId,
    List<_EditableItem> items,
    double taxAmount,
    double serviceAmount,
    DateTime? date,
  ) onSave;

  const _EditBillPage({
    required this.title,
    required this.paidByUserId,
    required this.items,
    required this.memberNames,
    required this.taxAmount,
    required this.serviceAmount,
    required this.onSave,
    this.initialDate,
  });

  @override
  State<_EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<_EditBillPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _svcCtrl;
  late String _paidByUserId;
  late List<_EditableItem> _items;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _taxCtrl = TextEditingController(
        text: widget.taxAmount > 0 ? widget.taxAmount.toStringAsFixed(2) : '');
    _svcCtrl = TextEditingController(
        text: widget.serviceAmount > 0
            ? widget.serviceAmount.toStringAsFixed(2)
            : '');
    _paidByUserId = widget.paidByUserId;
    _items = widget.items
        .map((e) => _EditableItem(
              id: e.id,
              description: e.description,
              amount: e.amount,
              assignedToUserIds: List.from(e.assignedToUserIds),
            ))
        .toList();
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate;
      _selectedTime = TimeOfDay.fromDateTime(widget.initialDate!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _taxCtrl.dispose();
    _svcCtrl.dispose();
    super.dispose();
  }

  // Show date picker and update selected date
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Show time picker and update selected time
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // Merge selected date and time into a single DateTime
  DateTime? get _combinedDate {
    if (_selectedDate == null) return null;
    final t = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        t.hour, t.minute);
  }

  // Format date as "DD Mon YYYY"
  String _formatDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // Format time as "HH:MM"
  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Add new empty item and immediately open its editor
  void _addItem() {
    setState(() {
      _items.add(_EditableItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        description: '',
        amount: 0,
        assignedToUserIds: widget.memberNames.keys.toList(),
      ));
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _openItemEditor(_items.length - 1);
    });
  }

  // Open dialog to edit item description, amount and assigned members
  void _openItemEditor(int index) {
    showDialog(
      context: context,
      builder: (_) => _ItemEditorDialog(
        item: _items[index],
        memberNames: widget.memberNames,
        onSave: (updated) => setState(() => _items[index] = updated),
      ),
    );
  }

  // Remove item at given index
  void _deleteItem(int index) => setState(() => _items.removeAt(index));

  // Pass edited bill data back to parent and close page
  void _save() {
    widget.onSave(
      _titleCtrl.text.trim().isEmpty ? widget.title : _titleCtrl.text.trim(),
      _paidByUserId,
      _items,
      double.tryParse(_taxCtrl.text) ?? 0,
      double.tryParse(_svcCtrl.text) ?? 0,
      _combinedDate,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        leadingWidth: 80,
        title: const Text('Edit Bill Draft',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          _Label('Bill Title'),
          TextField(
            controller: _titleCtrl,
            decoration: _fieldDecoration('e.g. KFC Lunch'),
          ),
          const SizedBox(height: 16),

          // Paid by
          _Label('Paid by'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: widget.memberNames.containsKey(_paidByUserId)
                  ? _paidByUserId
                  : null,
              hint: const Text('Select member',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: widget.memberNames.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _paidByUserId = v);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Date & time (optional)
          _Label('Tarikh & Masa (optional)'),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDate == null
                              ? 'Pilih tarikh'
                              : _formatDate(_selectedDate!),
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _selectedDate == null ? null : _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: _selectedDate == null
                          ? AppColors.surfaceVariant.withAlpha(120)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_outlined,
                            size: 16,
                            color: _selectedDate == null
                                ? AppColors.textSecondary.withAlpha(100)
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime == null
                              ? 'Masa'
                              : _formatTime(_selectedTime!),
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate == null
                                ? AppColors.textSecondary.withAlpha(100)
                                : _selectedTime == null
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.clear,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () =>
                      setState(() {
                        _selectedDate = null;
                        _selectedTime = null;
                      }),
                  tooltip: 'Clear date',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Items header
          Row(
            children: [
              _Label('Items'),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No items yet — tap Add Item',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),

          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final assigned = item.assignedToUserIds
                .map((id) => widget.memberNames[id] ?? id)
                .join(', ');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _openItemEditor(i),
                contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                title: Text(
                  item.description.isEmpty
                      ? '(no description)'
                      : item.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: item.description.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  assigned.isEmpty ? 'Split: all members' : 'For: $assigned',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.format(item.amount),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () => _deleteItem(i),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Tax & service charge
          _Label('Extras (optional)'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDecoration('Tax (RM)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _svcCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDecoration('Service charge (RM)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Item Editor Dialog ───────────────────────────────────────────────────────

class _ItemEditorDialog extends StatefulWidget {
  final _EditableItem item;
  final Map<String, String> memberNames;
  final Function(_EditableItem) onSave;

  const _ItemEditorDialog({
    required this.item,
    required this.memberNames,
    required this.onSave,
  });

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  late TextEditingController _descCtrl;
  late TextEditingController _amountCtrl;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.description);
    _amountCtrl = TextEditingController(
        text: widget.item.amount > 0
            ? widget.item.amount.toStringAsFixed(2)
            : '');
    _selected = Set.from(widget.item.assignedToUserIds);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // Save edited item and close dialog
  void _save() {
    widget.onSave(_EditableItem(
      id: widget.item.id,
      description: _descCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      assignedToUserIds: _selected.toList(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Item',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: _fieldDecoration('Item description'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration('Amount (RM)'),
            ),
            const SizedBox(height: 16),
            const Text('Split between:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.memberNames.entries.map((entry) {
                final isSelected = _selected.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value,
                      style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary)),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selected.add(entry.key);
                      } else {
                        _selected.remove(entry.key);
                      }
                    });
                  },
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppColors.surfaceVariant,
                  side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              _selected.isEmpty
                  ? 'No one selected'
                  : '${_selected.length} member(s) selected',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
