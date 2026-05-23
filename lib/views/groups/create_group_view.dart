import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:splitmate/controllers/groups_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/widgets/common/app_button.dart';

class CreateGroupView extends StatefulWidget {
  const CreateGroupView({super.key});

  @override
  State<CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GroupsController _controller = Get.find<GroupsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Group')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Group name',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Lunch Gang, Trip to KL',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can add members after creating the group.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  Obx(() => AppButton(
                        label: 'Create Group',
                        isLoading: _controller.isCreating.value,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _controller.createGroup(_nameCtrl.text.trim());
                          }
                        },
                      )),
                  Obx(() {
                    if (_controller.error.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_controller.error.value,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
