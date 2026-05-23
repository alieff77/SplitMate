import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/image_utils.dart';
import 'package:splitmate/widgets/common/app_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text('SplitMate',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Split bills with friends, no awkwardness.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 32),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Sign Up'),
                      Tab(text: 'Log In'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tab content
                SizedBox(
                  height: 560,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: const [
                      _SignUpForm(),
                      _LoginForm(),
                    ],
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

// ── Sign Up ────────────────────────────────────────────────────────────────

class _SignUpForm extends StatefulWidget {
  const _SignUpForm();

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  XFile? _qrFile;
  String? _qrBase64;
  bool _isCompressing = false;

  final AuthController _auth = Get.find<AuthController>();

  Future<void> _pickQr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isCompressing = true);
    try {
      final base64 = await ImageUtils.compressAndEncode(picked);
      setState(() {
        _qrFile = picked;
        _qrBase64 = base64;
      });
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString(),
            backgroundColor: AppColors.dangerLight,
            colorText: AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_qrBase64 == null) {
      Get.snackbar('Missing QR', 'Please upload your DuitNow QR code',
          backgroundColor: AppColors.pendingLight,
          colorText: AppColors.pending);
      return;
    }
    _auth.signUp(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      duitnowQrBase64: _qrBase64!,
      bankName: _bankCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person_outline)),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '01X-XXXXXXXX'),
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankCtrl,
            decoration: const InputDecoration(
                labelText: 'Bank Name (optional)',
                prefixIcon: Icon(Icons.account_balance_outlined),
                hintText: 'e.g. Maybank, CIMB'),
          ),
          const SizedBox(height: 16),

          // QR upload
          const Text('DuitNow QR Code',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _isCompressing ? null : _pickQr,
            child: Container(
              width: double.infinity,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _qrFile != null
                      ? AppColors.primary
                      : AppColors.border,
                  width: _qrFile != null ? 2 : 1,
                ),
              ),
              child: _isCompressing
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _qrFile != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'QR uploaded (${ImageUtils.getSizeKB(_qrBase64!)}KB) — tap to change',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 32, color: AppColors.textHint),
                            SizedBox(height: 6),
                            Text('Tap to upload DuitNow QR',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            Text('Max 200KB',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint)),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 20),

          Obx(() => AppButton(
                label: 'Create Account',
                isLoading: _auth.isLoading.value,
                onPressed: _submit,
              )),

          Obx(() {
            if (_auth.error.value.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_auth.error.value,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 13),
                  textAlign: TextAlign.center),
            );
          }),
        ],
      ),
    );
  }
}

// ── Log In ─────────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthController _auth = Get.find<AuthController>();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _auth.signIn(phone: _phoneCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your registered phone number to log in.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '01X-XXXXXXXX',
            ),
            keyboardType: TextInputType.phone,
            autofocus: false,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your phone number' : null,
          ),
          const SizedBox(height: 24),

          Obx(() => AppButton(
                label: 'Log In',
                isLoading: _auth.isLoading.value,
                onPressed: _submit,
              )),

          Obx(() {
            if (_auth.error.value.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _auth.error.value,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            );
          }),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Don\'t have an account? Switch to the Sign Up tab.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
