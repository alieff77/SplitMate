import 'package:flutter/material.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/bill_model.dart';

class BillDraftCard extends StatelessWidget {
  final BillDraft draft;
  final Map<String, String> memberNames;
  final VoidCallback onConfirm;
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
  Widget build(BuildContext context) {
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
                    draft.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(draft.totalAmount),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),

          // Paid by
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              'Paid by: ${memberNames[draft.paidByUserId] ?? draft.paidByUserId}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              children: draft.items.map((item) {
                final assigned = item.assignedToUserIds
                    .map((id) => memberNames[id] ?? id)
                    .join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '• ${item.description} ($assigned)',
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

          // Tax / service
          if (draft.taxAmount > 0 || draft.serviceChargeAmount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax + Service Charge',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text(
                    CurrencyFormatter.format(
                        draft.taxAmount + draft.serviceChargeAmount),
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
              children: draft.shares.map((share) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(memberNames[share.userId] ?? share.userId,
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
                    onPressed: isLoading ? null : onDiscard,
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
                    onPressed: isLoading ? null : onConfirm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: isLoading
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
