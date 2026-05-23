import 'package:splitmate/models/bill_model.dart';

class BillCalculationResult {
  final double subtotal;
  final double taxAmount;
  final double serviceChargeAmount;
  final double totalAmount;
  final List<BillShare> shares;

  const BillCalculationResult({
    required this.subtotal,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.totalAmount,
    required this.shares,
  });
}

class BillCalculator {
  static BillCalculationResult calculate({
    required List<BillItem> items,
    required double taxPercent,
    required double serviceChargePercent,
  }) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.amount);
    final taxAmount = _round(subtotal * (taxPercent / 100));
    final serviceChargeAmount = _round(subtotal * (serviceChargePercent / 100));
    final totalAmount = _round(subtotal + taxAmount + serviceChargeAmount);

    final Map<String, double> userSubtotals = {};
    for (final item in items) {
      if (item.assignedToUserIds.isEmpty) continue;
      final perPerson = item.amount / item.assignedToUserIds.length;
      for (final userId in item.assignedToUserIds) {
        userSubtotals[userId] = (userSubtotals[userId] ?? 0) + perPerson;
      }
    }

    final shares = userSubtotals.entries.map((entry) {
      final proportion = subtotal > 0 ? entry.value / subtotal : 0.0;
      final userTax = _round(taxAmount * proportion);
      final userService = _round(serviceChargeAmount * proportion);
      final amountOwed = _round(entry.value + userTax + userService);
      return BillShare(
        userId: entry.key,
        amountOwed: amountOwed,
        isPaid: false,
        paidAt: null,
        markedPaidByUserId: null,
        confirmedByPayer: false,
      );
    }).toList();

    // Fix rounding diff against last share
    if (shares.isNotEmpty) {
      final sharesSum = shares.fold(0.0, (s, sh) => s + sh.amountOwed);
      final diff = _round(totalAmount - sharesSum);
      if (diff.abs() > 0) {
        shares[0] = shares[0].copyWith(amountOwed: _round(shares[0].amountOwed + diff));
      }
    }

    return BillCalculationResult(
      subtotal: subtotal,
      taxAmount: taxAmount,
      serviceChargeAmount: serviceChargeAmount,
      totalAmount: totalAmount,
      shares: shares,
    );
  }

  static double _round(double v) => (v * 100).round() / 100;
}
