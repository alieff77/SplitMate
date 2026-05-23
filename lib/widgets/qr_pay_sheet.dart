import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/currency_formatter.dart';
import 'package:splitmate/models/user_model.dart';

class QrPaySheet extends StatelessWidget {
  final UserModel payer;
  final double amount;
  final VoidCallback onConfirmPaid;

  const QrPaySheet({
    super.key,
    required this.payer,
    required this.amount,
    required this.onConfirmPaid,
  });

  static Future<void> show({
    required BuildContext context,
    required UserModel payer,
    required double amount,
    required VoidCallback onConfirmPaid,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrPaySheet(
        payer: payer,
        amount: amount,
        onConfirmPaid: onConfirmPaid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Payer avatar + name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withAlpha(26),
                    child: Text(
                      payer.name.isNotEmpty
                          ? payer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pay ${payer.name}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  if (payer.bankName.isNotEmpty)
                    Text(payer.bankName,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            Center(
              child: Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // QR Code
            if (payer.duitnowQrBase64.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _decodeBase64(payer.duitnowQrBase64),
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.qr_code,
                        size: 120,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: Icon(Icons.qr_code, size: 120, color: AppColors.textHint),
              ),
            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '1. Open your banking app\n2. Scan this DuitNow QR code\n3. Enter ${CurrencyFormatter.format(amount)}\n4. Complete payment, then tap "I\'ve Paid" below',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.6),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirmPaid();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("I've Paid",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Uint8List _decodeBase64(String dataUrl) {
    final data =
        dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return base64Decode(data);
  }
}
