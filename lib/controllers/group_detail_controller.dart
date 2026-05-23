import 'package:get/get.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/models/message_model.dart';
import 'package:splitmate/services/bill_service.dart';
import 'package:splitmate/services/group_service.dart';
import 'package:splitmate/services/user_service.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/core/utils/settlement_optimizer.dart';

class GroupDetailController extends GetxController {
  final GroupService _groupService = GroupService();
  final BillService _billService = BillService();
  final UserService _userService = UserService();

  final RxBool isAddingMember = false.obs;
  final RxString addMemberError = ''.obs;

  final Rx<GroupModel?> group = Rx<GroupModel?>(null);
  final RxList<BillModel> bills = <BillModel>[].obs;
  final RxBool isLoading = true.obs;

  // Balance tab
  final RxList<BalanceEntry> settlements = <BalanceEntry>[].obs;
  final RxMap<String, double> memberNetBalances = <String, double>{}.obs;

  AuthController get _auth => Get.find<AuthController>();

  String get groupId => Get.parameters['id'] ?? '';

  @override
  void onInit() {
    super.onInit();
    _watchGroup();
    _watchBills();
  }

  void _watchGroup() {
    _groupService.watchGroup(groupId).listen((g) {
      group.value = g;
    });
  }

  void _watchBills() {
    _billService.watchBills(groupId).listen((list) {
      bills.value = list;
      isLoading.value = false;
      _computeBalances(list);
    });
  }

  void _computeBalances(List<BillModel> billList) {
    final Map<String, double> nets = {};
    final grp = group.value;
    if (grp == null) return;

    for (final userId in grp.memberIds) {
      nets[userId] = 0;
    }

    for (final bill in billList) {
      for (final share in bill.shares) {
        if (share.isPaid) continue;
        // The person who paid is owed money
        nets[bill.paidByUserId] =
            (nets[bill.paidByUserId] ?? 0) + share.amountOwed;
        // The debtor owes money
        nets[share.userId] = (nets[share.userId] ?? 0) - share.amountOwed;
      }
      // Payer doesn't owe themselves
      for (final share in bill.shares) {
        if (share.isPaid) continue;
        if (share.userId == bill.paidByUserId) {
          nets[bill.paidByUserId] =
              (nets[bill.paidByUserId] ?? 0) - share.amountOwed;
          nets[share.userId] = (nets[share.userId] ?? 0) + share.amountOwed;
        }
      }
    }

    memberNetBalances.value = nets.map(
      (k, v) => MapEntry(k, (v * 100).round() / 100),
    );

    final balanceList = nets.entries
        .map((e) => NetBalance(
              userId: e.key,
              userName: grp.memberNames[e.key] ?? e.key,
              net: e.value,
            ))
        .toList();

    settlements.value = SettlementOptimizer.compute(balanceList);
  }

  Future<bool> addMemberByPhone(String phone) async {
    isAddingMember.value = true;
    addMemberError.value = '';
    try {
      final member = await _userService.getUserByPhone(phone);
      if (member == null) {
        addMemberError.value = 'No user found with that phone number.';
        return false;
      }
      if (group.value?.memberIds.contains(member.id) == true) {
        addMemberError.value = 'That person is already in this group.';
        return false;
      }
      await _groupService.addMember(
        groupId: groupId,
        userId: member.id,
        userName: member.name,
      );
      await _userService.addGroupToUser(member.id, groupId);
      return true;
    } catch (e) {
      addMemberError.value = e.toString();
      return false;
    } finally {
      isAddingMember.value = false;
    }
  }

  double get myNetBalance => memberNetBalances[_auth.userId] ?? 0;

  BillModel? billById(String billId) {
    try {
      return bills.firstWhere((b) => b.id == billId);
    } catch (_) {
      return null;
    }
  }

  List<BillModel> get unpaidBillsForMe {
    final userId = _auth.userId;
    return bills.where((bill) {
      return bill.shares.any((s) => s.userId == userId && !s.isPaid);
    }).toList();
  }

  bool get hasOldUnpaidBills {
    final userId = _auth.userId;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return bills.any((bill) =>
        bill.createdAt.toDate().isBefore(sevenDaysAgo) &&
        bill.shares.any((s) => s.userId == userId && !s.isPaid));
  }
}
