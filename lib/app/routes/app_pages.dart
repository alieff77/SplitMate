import 'package:get/get.dart';
import 'package:splitmate/app/routes/app_routes.dart';
import 'package:splitmate/controllers/bill_controller.dart';
import 'package:splitmate/controllers/chat_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/controllers/groups_controller.dart';
import 'package:splitmate/controllers/profile_controller.dart';
import 'package:splitmate/views/auth/login_view.dart';
import 'package:splitmate/views/bills/bill_detail_view.dart';
import 'package:splitmate/views/bills/create_bill_view.dart';
import 'package:splitmate/views/group_detail/group_detail_view.dart';
import 'package:splitmate/views/groups/create_group_view.dart';
import 'package:splitmate/views/groups/groups_view.dart';
import 'package:splitmate/views/profile/profile_view.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: AppRoutes.groups,
      page: () => const GroupsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => GroupsController());
      }),
    ),
    GetPage(
      name: AppRoutes.createGroup,
      page: () => const CreateGroupView(),
    ),
    GetPage(
      name: AppRoutes.groupDetail,
      page: () => const GroupDetailView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => GroupDetailController(), fenix: true);
        Get.lazyPut(() => BillController(), fenix: true);
        Get.lazyPut(() => ChatController(), fenix: true);
      }),
    ),
    GetPage(
      name: AppRoutes.createBill,
      page: () => const CreateBillView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => BillController(), fenix: true);
      }),
    ),
    GetPage(
      name: AppRoutes.billDetail,
      page: () => const BillDetailView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => GroupDetailController(), fenix: true);
        Get.lazyPut(() => BillController(), fenix: true);
      }),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileView(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => ProfileController());
      }),
    ),
  ];
}
