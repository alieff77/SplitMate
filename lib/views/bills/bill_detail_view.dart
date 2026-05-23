import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/bill_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/services/user_service.dart';
import 'package:splitmate/widgets/qr_pay_sheet.dart';

class BillDetailView extends StatelessWidget {
  const BillDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final groupCtrl = Get.find<GroupDetailController>();
    final billCtrl = Get.find<BillController>();
    final auth = Get.find<AuthController>();
    final billId = Get.parameters['billId'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Obx(() {
            final bill = groupCtrl.billById(billId);
            if (bill == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final group = groupCtrl.group.value;
            final memberNames = group?.memberNames ?? {};
            final payerName =
                memberNames[bill.paidByUserId] ?? 'Unknown';
            final dateStr = DateFormat('d MMMM yyyy, h:mm a')
                .format(bill.createdAt.toDate());

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Paid by $payerName · $dateStr',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 16),
                      Text(
                        CurrencyFormatter.format(bill.totalAmount),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt image
                if (bill.receiptImageBase64 != null)
                  _ReceiptImage(base64: bill.receiptImageBase64!),

                // Items breakdown
                _SectionHeader(title: 'Items'),
                ...bill.items.map((item) => _ItemRow(
                    item: item, memberNames: memberNames)),

                // Tax / service
                if (bill.taxAmount > 0 || bill.serviceChargeAmount > 0)
                  _TaxRow(bill: bill),

                const SizedBox(height: 8),

                // Who owes what
                _SectionHeader(title: 'Who Owes What'),
                ...bill.shares.map((share) {
                  final isMe = share.userId == auth.userId;
                  final isPayer = bill.paidByUserId == auth.userId;
                  return _ShareRow(
                    share: share,
                    name: memberNames[share.userId] ?? 'Unknown',
                    isMe: isMe,
                    isPayer: bill.paidByUserId == share.userId,
                    canPay: isMe && !share.isPaid &&
                        bill.paidByUserId != auth.userId,
                    canConfirm: isPayer && !share.confirmedByPayer &&
                        share.isPaid &&
                        share.userId != auth.userId,
                    onPay: () => _openQrPay(
                        context, bill, share, billCtrl, auth),
                    onConfirm: () => billCtrl.confirmReceived(
                      groupId: groupCtrl.groupId,
                      billId: bill.id,
                      debtorId: share.userId,
                    ),
                  );
                }),

                const SizedBox(height: 80),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _openQrPay(
    BuildContext context,
    BillModel bill,
    BillShare share,
    BillController billCtrl,
    AuthController auth,
  ) async {
    final groupCtrl = Get.find<GroupDetailController>();
    final userService = UserService();
    final payer = await userService.getUser(bill.paidByUserId);
    if (payer == null) {
      Get.snackbar('Error', 'Could not load payer QR code');
      return;
    }
    if (!context.mounted) return;
    await QrPaySheet.show(
      context: context,
      payer: payer,
      amount: share.amountOwed,
      onConfirmPaid: () => billCtrl.markSharePaid(
        groupId: groupCtrl.groupId,
        billId: bill.id,
        payerName: payer.name,
        amount: share.amountOwed,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final BillItem item;
  final Map<String, String> memberNames;
  const _ItemRow({required this.item, required this.memberNames});

  @override
  Widget build(BuildContext context) {
    final assigned =
        item.assignedToUserIds.map((id) => memberNames[id] ?? id).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                if (assigned.isNotEmpty)
                  Text(assigned,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(CurrencyFormatter.format(item.amount),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final BillModel bill;
  const _TaxRow({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 20),
        if (bill.taxAmount > 0)
          _SubtotalLine(
              label: 'Tax', amount: bill.taxAmount),
        if (bill.serviceChargeAmount > 0)
          _SubtotalLine(
              label: 'Service Charge',
              amount: bill.serviceChargeAmount),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(CurrencyFormatter.format(bill.totalAmount),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _SubtotalLine extends StatelessWidget {
  final String label;
  final double amount;
  const _SubtotalLine({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(CurrencyFormatter.format(amount),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final BillShare share;
  final String name;
  final bool isMe;
  final bool isPayer;
  final bool canPay;
  final bool canConfirm;
  final VoidCallback onPay;
  final VoidCallback onConfirm;

  const _ShareRow({
    required this.share,
    required this.name,
    required this.isMe,
    required this.isPayer,
    required this.canPay,
    required this.canConfirm,
    required this.onPay,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isMe && !share.isPaid && !isPayer
                ? AppColors.pending
                : AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? '$name (you)' : name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(
                  share.isPaid
                      ? share.confirmedByPayer
                          ? 'Confirmed received'
                          : 'Paid — waiting confirmation'
                      : CurrencyFormatter.format(share.amountOwed),
                  style: TextStyle(
                      fontSize: 12,
                      color: share.isPaid
                          ? AppColors.success
                          : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (canPay)
            ElevatedButton(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pay',
                  style: TextStyle(fontSize: 13)),
            )
          else if (canConfirm)
            OutlinedButton(
              onPressed: onConfirm,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Confirm',
                  style: TextStyle(fontSize: 13)),
            )
          else
            Icon(
              share.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
              color: share.isPaid ? AppColors.success : AppColors.border,
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _ReceiptImage extends StatelessWidget {
  final String base64;
  const _ReceiptImage({required this.base64});

  @override
  Widget build(BuildContext context) {
    final data = base64.contains(',') ? base64.split(',').last : base64;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Receipt',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(data),
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
