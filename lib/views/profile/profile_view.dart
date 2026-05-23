import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/profile_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/image_utils.dart';
import 'package:splitmate/widgets/common/app_button.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bankCtrl;

  final ProfileController _ctrl = Get.find<ProfileController>();
  final AuthController _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser.value;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _bankCtrl = TextEditingController(text: user?.bankName ?? '');
  }

  Future<void> _pickQr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _ctrl.updateQrCode(picked);
    if (_ctrl.successMessage.value.isNotEmpty) {
      Get.snackbar('Success', _ctrl.successMessage.value,
          backgroundColor: AppColors.successLight,
          colorText: AppColors.success);
    }
  }

  void _save() {
    _ctrl.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      bankName: _bankCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _auth.signOut,
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Obx(() {
            final user = _auth.currentUser.value;
            if (user == null) return const SizedBox.shrink();

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withAlpha(26),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('ID: ${user.id.substring(0, 8)}...',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ),
                const SizedBox(height: 24),

                // Fields
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bankCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      prefixIcon: Icon(Icons.account_balance_outlined)),
                ),
                const SizedBox(height: 24),

                Obx(() => AppButton(
                      label: 'Save Profile',
                      isLoading: _ctrl.isSaving.value,
                      onPressed: _save,
                    )),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // DuitNow QR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DuitNow QR Code',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    TextButton.icon(
                      onPressed: _pickQr,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Update'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (user.duitnowQrBase64.isNotEmpty)
                  _QrPreview(
                    base64: user.duitnowQrBase64,
                    sizeKB: ImageUtils.getSizeKB(user.duitnowQrBase64),
                  )
                else
                  GestureDetector(
                    onTap: _pickQr,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code,
                                size: 36, color: AppColors.textHint),
                            SizedBox(height: 6),
                            Text('Tap to upload QR',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),

                Obx(() {
                  if (_ctrl.error.value.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_ctrl.error.value,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                  );
                }),
                const SizedBox(height: 40),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  final String base64;
  final int sizeKB;
  const _QrPreview({required this.base64, required this.sizeKB});

  @override
  Widget build(BuildContext context) {
    final data = base64.contains(',') ? base64.split(',').last : base64;
    Uint8List bytes;
    try {
      bytes = base64Decode(data);
    } catch (_) {
      return const Icon(Icons.broken_image, color: AppColors.textHint);
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes,
              width: double.infinity,
              height: 200,
              fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        Text('${sizeKB}KB',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }
}
