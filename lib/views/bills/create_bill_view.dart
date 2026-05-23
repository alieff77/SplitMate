import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitmate/controllers/bill_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/core/utils/image_utils.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/widgets/common/app_button.dart';
import 'package:uuid/uuid.dart';

class CreateBillView extends StatefulWidget {
  const CreateBillView({super.key});

  @override
  State<CreateBillView> createState() => _CreateBillViewState();
}

class _CreateBillViewState extends State<CreateBillView> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _serviceCtrl = TextEditingController(text: '0');

  final BillController _ctrl = Get.find<BillController>();
  final GroupDetailController _groupCtrl = Get.find<GroupDetailController>();
  final _uuid = const Uuid();

  String? _selectedPayerId;
  final List<_ItemRow> _itemRows = [];
  XFile? _receiptFile;

  @override
  void initState() {
    super.initState();
    _ctrl.items.clear();
    _addItem();
  }

  void _addItem() {
    final id = _uuid.v4();
    setState(() {
      _itemRows.add(_ItemRow(id: id));
      _ctrl.items.add(BillItem(
          id: id, description: '', amount: 0, assignedToUserIds: []));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemRows.removeAt(index);
      _ctrl.removeItem(index);
    });
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final base64 = await ImageUtils.compressAndEncode(picked);
      setState(() => _receiptFile = picked);
      _ctrl.receiptBase64.value = base64;
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      Get.snackbar('Missing title', 'Please enter a bill title');
      return;
    }
    if (_selectedPayerId == null) {
      Get.snackbar('Missing payer', 'Please select who paid');
      return;
    }
    if (_ctrl.items.every((i) => i.amount <= 0)) {
      Get.snackbar('No items', 'Add at least one item with an amount');
      return;
    }
    _ctrl
      ..title.value = _titleCtrl.text.trim()
      ..paidByUserId.value = _selectedPayerId!
      ..notes.value = _notesCtrl.text.trim()
      ..taxPercent.value = double.tryParse(_taxCtrl.text) ?? 0
      ..serviceChargePercent.value =
          double.tryParse(_serviceCtrl.text) ?? 0;
    _ctrl.submitBill();
  }

  @override
  Widget build(BuildContext context) {
    final group = _groupCtrl.group.value;
    final members = group?.memberNames ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Bill Title',
                    hintText: 'e.g. Dinner at Kopitiam'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),

              // Paid by
              DropdownButtonFormField<String>(
                initialValue: _selectedPayerId,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: members.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPayerId = v),
              ),
              const SizedBox(height: 20),

              // Receipt upload
              Row(
                children: [
                  const Text('Receipt (optional)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(_receiptFile != null ? 'Change' : 'Upload'),
                  ),
                ],
              ),
              if (_receiptFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FutureBuilder<Uint8List>(
                    future: _receiptFile!.readAsBytes(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox(height: 120);
                      return Image.memory(snap.data!,
                          height: 120, fit: BoxFit.cover);
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // Items header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Items',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add item'),
                  ),
                ],
              ),

              // Item rows
              ...List.generate(_itemRows.length, (i) {
                return _ItemFormRow(
                  index: i,
                  members: members,
                  ctrl: _ctrl,
                  onRemove: _itemRows.length > 1 ? () => _removeItem(i) : null,
                );
              }),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Tax / service charge
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _taxCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tax %', suffixText: '%'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _ctrl.taxPercent.value =
                              double.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _serviceCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Service %', suffixText: '%'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          _ctrl.serviceChargePercent.value =
                              double.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total preview
              Obx(() {
                final calc = _ctrl.calculation;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                      Text(
                        CurrencyFormatter.format(calc.totalAmount),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Any extra info...'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              Obx(() => AppButton(
                    label: 'Save Bill',
                    isLoading: _ctrl.isSubmitting.value,
                    onPressed: _submit,
                  )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow {
  final String id;
  _ItemRow({required this.id});
}

class _ItemFormRow extends StatefulWidget {
  final int index;
  final Map<String, String> members;
  final BillController ctrl;
  final VoidCallback? onRemove;

  const _ItemFormRow({
    required this.index,
    required this.members,
    required this.ctrl,
    this.onRemove,
  });

  @override
  State<_ItemFormRow> createState() => _ItemFormRowState();
}

class _ItemFormRowState extends State<_ItemFormRow> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amtCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.ctrl.items[widget.index];
    _descCtrl = TextEditingController(text: item.description);
    _amtCtrl = TextEditingController(
        text: item.amount > 0 ? item.amount.toStringAsFixed(2) : '');
  }

  void _update() {
    if (widget.index >= widget.ctrl.items.length) return;
    final current = widget.ctrl.items[widget.index];
    widget.ctrl.updateItem(
      widget.index,
      current.copyWith(
        description: _descCtrl.text,
        amount: double.tryParse(_amtCtrl.text) ?? 0,
      ),
    );
  }

  void _toggleMember(String uid, bool selected) {
    if (widget.index >= widget.ctrl.items.length) return;
    final current = widget.ctrl.items[widget.index];
    final ids = List<String>.from(current.assignedToUserIds);
    if (selected) {
      if (!ids.contains(uid)) ids.add(uid);
    } else {
      ids.remove(uid);
    }
    widget.ctrl.updateItem(
        widget.index, current.copyWith(assignedToUserIds: ids));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.index < widget.ctrl.items.length
        ? widget.ctrl.items[widget.index]
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Item name',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  onChanged: (_) => _update(),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amtCtrl,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: 'RM ',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _update(),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.danger, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Assign to:',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: widget.members.entries.map((e) {
              final isSelected =
                  item?.assignedToUserIds.contains(e.key) ?? false;
              return FilterChip(
                label: Text(e.value,
                    style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary)),
                selected: isSelected,
                onSelected: (v) => _toggleMember(e.key, v),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
