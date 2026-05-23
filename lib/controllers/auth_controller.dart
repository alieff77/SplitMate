import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitmate/models/user_model.dart';
import 'package:splitmate/services/auth_service.dart';
import 'package:splitmate/services/user_service.dart';
import 'package:splitmate/app/routes/app_routes.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  static const _userIdKey = 'splitmate_user_id';

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId != null) {
      final user = await _userService.getUser(userId);
      if (user != null) {
        currentUser.value = user;
        _watchUser(userId);
        Get.offAllNamed(AppRoutes.groups);
        return;
      }
      await prefs.remove(_userIdKey);
    }
  }

  void _watchUser(String userId) {
    _userService.watchUser(userId).listen((user) {
      currentUser.value = user;
    });
  }

  Future<void> signUp({
    required String name,
    required String phone,
    required String duitnowQrBase64,
    required String bankName,
  }) async {
    isLoading.value = true;
    error.value = '';
    try {
      final user = await _authService.signUpWithProfile(
        name: name,
        phone: phone,
        duitnowQrBase64: duitnowQrBase64,
        bankName: bankName,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.id);
      currentUser.value = user;
      _watchUser(user.id);
      Get.offAllNamed(AppRoutes.groups);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signIn({required String phone}) async {
    isLoading.value = true;
    error.value = '';
    try {
      final user = await _userService.getUserByPhone(phone);
      if (user == null) {
        error.value = 'No account found with that phone number.';
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.id);
      currentUser.value = user;
      _watchUser(user.id);
      Get.offAllNamed(AppRoutes.groups);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  bool get isLoggedIn => currentUser.value != null;
  String get userId => currentUser.value?.id ?? '';
  String get userName => currentUser.value?.name ?? '';
}
