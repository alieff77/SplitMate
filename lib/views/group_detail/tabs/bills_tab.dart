import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:splitmate/app/routes/app_routes.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/widgets/bill_card_widget.dart';
import 'package:splitmate/widgets/common/empty_state_widget.dart';

class BillsTab extends StatelessWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GroupDetailController>();
    final auth = Get.find<AuthController>();

    return Obx(() {
      if (ctrl.isLoading.value) {
        return _SkeletonBillList();
      }
      if (ctrl.bills.isEmpty) {
        return EmptyStateWidget(
          emoji: '🧾',
          title: 'No bills yet',
          subtitle: 'Add your first bill or let the AI parse it from chat.',
          action: ElevatedButton.icon(
            onPressed: () =>
                Get.toNamed(AppRoutes.createBillPath(ctrl.groupId)),
            icon: const Icon(Icons.add),
            label: const Text('Add Bill'),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: ctrl.bills.length,
        itemBuilder: (_, i) {
          final bill = ctrl.bills[i];
          return BillCardWidget(
            bill: bill,
            currentUserId: auth.userId,
            memberNames: ctrl.group.value?.memberNames ?? {},
            onTap: () =>
                Get.toNamed(AppRoutes.billDetailPath(ctrl.groupId, bill.id)),
          );
        },
      );
    });
  }
}

class _SkeletonBillList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 4,
      itemBuilder: (_, _) => const _SkeletonBillCard(),
    );
  }
}

class _SkeletonBillCard extends StatefulWidget {
  const _SkeletonBillCard();

  @override
  State<_SkeletonBillCard> createState() => _SkeletonBillCardState();
}

class _SkeletonBillCardState extends State<_SkeletonBillCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 14, width: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 22, width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 11, width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 6, width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
