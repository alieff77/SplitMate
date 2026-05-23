import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/bill_model.dart';

class BillCardWidget extends StatelessWidget {
  final BillModel bill;
  final String currentUserId;
  final Map<String, String> memberNames;
  final VoidCallback onTap;

  const BillCardWidget({
    super.key,
    required this.bill,
    required this.currentUserId,
    required this.memberNames,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final myShare = bill.shares.where((s) => s.userId == currentUserId).firstOrNull;
    final isPaidByMe = bill.paidByUserId == currentUserId;
    final payerName = memberNames[bill.paidByUserId] ?? 'Unknown';
    final dateStr = DateFormat('d MMM').format(bill.createdAt.toDate());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bill.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr · Paid by $payerName',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(bill.totalAmount),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (myShare != null && !isPaidByMe) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your share: ${CurrencyFormatter.format(myShare.amountOwed)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: myShare.isPaid
                            ? AppColors.successLight
                            : AppColors.pendingLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        myShare.isPaid ? '✓ Paid' : '⏳ Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: myShare.isPaid
                              ? AppColors.success
                              : AppColors.pending,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isPaidByMe) ...[
                const SizedBox(height: 10),
                _buildPaymentProgress(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentProgress() {
    final othersShares =
        bill.shares.where((s) => s.userId != bill.paidByUserId).toList();
    final paidCount = othersShares.where((s) => s.isPaid).length;
    final total = othersShares.length;
    if (total == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? paidCount / total : 0,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$paidCount/$total paid back',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
