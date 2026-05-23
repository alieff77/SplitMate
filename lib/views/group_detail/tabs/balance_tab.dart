import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/widgets/common/empty_state_widget.dart';

class BalanceTab extends StatelessWidget {
  const BalanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GroupDetailController>();
    final auth = Get.find<AuthController>();

    return Obx(() {
      final group = ctrl.group.value;
      if (group == null || ctrl.bills.isEmpty) {
        return const EmptyStateWidget(
          emoji: '⚖️',
          title: 'All settled!',
          subtitle: 'No outstanding balances in this group.',
        );
      }

      final settlements = ctrl.settlements;
      final nets = ctrl.memberNetBalances;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // My balance summary
          _buildMyBalanceCard(auth.userId, auth.userName, ctrl.myNetBalance),
          const SizedBox(height: 16),

          // All member balances
          const Text('Member Balances',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...group.memberIds.map((uid) {
            final name = group.memberNames[uid] ?? uid;
            final net = nets[uid] ?? 0;
            final isMe = uid == auth.userId;
            return _MemberBalanceRow(
                name: isMe ? '$name (you)' : name, net: net);
          }),

          if (settlements.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Suggested Settlements',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...settlements.map((s) => _SettlementRow(
                  from: s.fromUserName,
                  to: s.toUserName,
                  amount: s.amount,
                  isMe: s.fromUserId == auth.userId,
                )),
          ],
          const SizedBox(height: 80),
        ],
      );
    });
  }

  Widget _buildMyBalanceCard(String userId, String name, double net) {
    final isOwed = net > 0.01;
    final isOwe = net < -0.01;
    final isSettled = !isOwed && !isOwe;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwed
              ? [AppColors.primary, AppColors.primaryDark]
              : isOwe
                  ? [AppColors.pending, const Color(0xFFea580c)]
                  : [AppColors.textSecondary, AppColors.textHint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Balance',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            isSettled
                ? 'All settled up! 🎉'
                : isOwed
                    ? 'You are owed'
                    : 'You owe',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          if (!isSettled) ...[
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(net.abs()),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberBalanceRow extends StatelessWidget {
  final String name;
  final double net;

  const _MemberBalanceRow({required this.name, required this.net});

  @override
  Widget build(BuildContext context) {
    final isOwed = net > 0.01;
    final isOwe = net < -0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary))),
          Text(
            isOwed
                ? '+${CurrencyFormatter.format(net)}'
                : isOwe
                    ? CurrencyFormatter.format(net)
                    : 'Settled',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isOwed
                  ? AppColors.success
                  : isOwe
                      ? AppColors.pending
                      : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final String from;
  final String to;
  final double amount;
  final bool isMe;

  const _SettlementRow(
      {required this.from,
      required this.to,
      required this.amount,
      required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.pendingLight
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: AppColors.pending) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                children: [
                  TextSpan(
                      text: from,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' pays '),
                  TextSpan(
                      text: to,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isMe ? AppColors.pending : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
