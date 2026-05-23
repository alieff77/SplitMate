class CurrencyFormatter {
  static String format(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  static String formatCompact(double amount) {
    if (amount >= 1000) {
      return 'RM ${(amount / 1000).toStringAsFixed(1)}k';
    }
    return format(amount);
  }
}
