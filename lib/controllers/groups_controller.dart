import 'package:get/get.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/services/bill_service.dart';
import 'package:splitmate/services/group_service.dart';
import 'package:splitmate/services/user_service.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/app/routes/app_routes.dart';

class GroupsController extends GetxController {
  final GroupService _groupService = GroupService();
  final BillService _billService = BillService();
  final UserService _userService = UserService();

  final RxList<GroupModel> groups = <GroupModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  final RxString error = ''.obs;

  // Balance cache: groupId -> net amount for current user
  final RxMap<String, double> groupBalances = <String, double>{}.obs;

  AuthController get _auth => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    _watchGroups();
  }

  void _watchGroups() {
    final userId = _auth.userId;
    if (userId.isEmpty) return;
    isLoading.value = true;
    _groupService.watchUserGroups(userId).listen(
      (list) {
        groups.value = list;
        isLoading.value = false;
        _loadBalances(list);
      },
      onError: (e) {
        error.value = e.toString();
        isLoading.value = false;
      },
    );
  }

  Future<void> _loadBalances(List<GroupModel> groupList) async {
    final userId = _auth.userId;
    await Future.wait(groupList.map((group) async {
      final bills = await _billService.getBills(group.id);
      double net = 0;
      for (final bill in bills) {
        for (final share in bill.shares) {
          if (share.isPaid) continue;
          if (share.userId == userId && bill.paidByUserId != userId) {
            net -= share.amountOwed;
          } else if (bill.paidByUserId == userId && share.userId != userId) {
            net += share.amountOwed;
          }
        }
      }
      groupBalances[group.id] = (net * 100).round() / 100;
    }));
  }

  Future<void> createGroup(String name) async {
    isCreating.value = true;
    error.value = '';
    try {
      final group = await _groupService.createGroup(
        name: name,
        creatorId: _auth.userId,
        creatorName: _auth.userName,
      );
      await _userService.addGroupToUser(_auth.userId, group.id);
      Get.back();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isCreating.value = false;
    }
  }

  Future<void> addMember({
    required String groupId,
    required String memberId,
  }) async {
    final member = await _userService.getUser(memberId);
    if (member == null) {
      error.value = 'User not found';
      return;
    }
    await _groupService.addMember(
      groupId: groupId,
      userId: memberId,
      userName: member.name,
    );
    await _userService.addGroupToUser(memberId, groupId);
  }

  Future<void> reloadBalances() => _loadBalances(groups);

  void goToGroup(String groupId) {
    Get.toNamed(AppRoutes.groupDetailPath(groupId));
  }
}
