import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/core/utils/image_utils.dart';
import 'package:splitmate/services/user_service.dart';

class ProfileController extends GetxController {
  final UserService _userService = UserService();

  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;
  final RxString successMessage = ''.obs;

  AuthController get _auth => Get.find<AuthController>();

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String bankName,
  }) async {
    isSaving.value = true;
    error.value = '';
    try {
      await _userService.updateUser(_auth.userId, {
        'name': name,
        'phone': phone,
        'bankName': bankName,
      });
      successMessage.value = 'Profile updated!';
    } catch (e) {
      error.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateQrCode(XFile xFile) async {
    isSaving.value = true;
    error.value = '';
    try {
      final base64 = await ImageUtils.compressAndEncode(xFile);
      await _userService.updateUser(_auth.userId, {
        'duitnowQrBase64': base64,
      });
      successMessage.value = 'QR code updated!';
    } catch (e) {
      error.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}
