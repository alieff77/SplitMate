import 'package:flutter/material.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/group_model.dart';

class GroupCardWidget extends StatelessWidget {
  final GroupModel group;
  final double netBalance;
  final VoidCallback onTap;

  const GroupCardWidget({
    super.key,
    required this.group,
    required this.netBalance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOwed = netBalance > 0;
    final isSettled = netBalance.abs() < 0.01;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty
                        ? group.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberIds.length} member${group.memberIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Balance badge
              if (!isSettled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOwed
                        ? AppColors.successLight
                        : AppColors.pendingLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOwed
                        ? '+${CurrencyFormatter.format(netBalance)}'
                        : CurrencyFormatter.format(netBalance),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isOwed ? AppColors.success : AppColors.pending,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Settled',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
