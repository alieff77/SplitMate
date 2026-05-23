import 'package:splitmate/models/message_model.dart';

class NetBalance {
  final String userId;
  final String userName;
  double net; // positive = owed to this person, negative = owes

  NetBalance({required this.userId, required this.userName, required this.net});
}

class SettlementOptimizer {
  static List<BalanceEntry> compute(List<NetBalance> balances) {
    final creditors = balances
        .where((b) => b.net > 0.005)
        .map((b) => NetBalance(userId: b.userId, userName: b.userName, net: b.net))
        .toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    final debtors = balances
        .where((b) => b.net < -0.005)
        .map((b) => NetBalance(userId: b.userId, userName: b.userName, net: b.net))
        .toList()
      ..sort((a, b) => a.net.compareTo(b.net));

    final transactions = <BalanceEntry>[];
    int ci = 0, di = 0;

    while (ci < creditors.length && di < debtors.length) {
      final creditor = creditors[ci];
      final debtor = debtors[di];
      final amount = creditor.net < -debtor.net ? creditor.net : -debtor.net;
      final rounded = (amount * 100).round() / 100;

      if (rounded > 0) {
        transactions.add(BalanceEntry(
          fromUserId: debtor.userId,
          fromUserName: debtor.userName,
          toUserId: creditor.userId,
          toUserName: creditor.userName,
          amount: rounded,
        ));
      }

      creditor.net -= amount;
      debtor.net += amount;

      if (creditor.net.abs() < 0.005) ci++;
      if (debtor.net.abs() < 0.005) di++;
    }

    return transactions;
  }
}
