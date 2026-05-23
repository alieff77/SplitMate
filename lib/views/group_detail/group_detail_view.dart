import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:splitmate/app/routes/app_routes.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/views/group_detail/tabs/balance_tab.dart';
import 'package:splitmate/views/group_detail/tabs/bills_tab.dart';
import 'package:splitmate/views/group_detail/tabs/chat_tab.dart';

class GroupDetailView extends StatelessWidget {
  const GroupDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GroupDetailController>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() =>
              Text(ctrl.group.value?.name ?? 'Group')),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'Add member',
              onPressed: () => _showAddMemberDialog(context, ctrl),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bills'),
              Tab(text: 'Balance'),
              Tab(text: 'Chat'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const TabBarView(
              children: [
                BillsTab(),
                BalanceTab(),
                ChatTab(),
              ],
            ),
          ),
        ),
        floatingActionButton: _AddBillFab(groupId: ctrl.groupId),
      ),
    );
  }

  void _showAddMemberDialog(
      BuildContext context, GroupDetailController ctrl) {
    final phoneCtrl = TextEditingController();
    ctrl.addMemberError.value = '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter their registered phone number:',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '01X-XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            Obx(() {
              if (ctrl.addMemberError.value.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(ctrl.addMemberError.value,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12)),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          Obx(() => ElevatedButton(
                onPressed: ctrl.isAddingMember.value
                    ? null
                    : () async {
                        if (phoneCtrl.text.trim().isEmpty) return;
                        final ok = await ctrl
                            .addMemberByPhone(phoneCtrl.text.trim());
                        if (ok) {
                          Get.back();
                          Get.snackbar('Member added', '',
                              duration: const Duration(seconds: 2));
                        }
                      },
                child: ctrl.isAddingMember.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              )),
        ],
      ),
    );
  }
}

class _AddBillFab extends StatelessWidget {
  final String groupId;
  const _AddBillFab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    // Only show FAB on Bills tab
    return FloatingActionButton.extended(
      onPressed: () => Get.toNamed(AppRoutes.createBillPath(groupId)),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Add Bill',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
