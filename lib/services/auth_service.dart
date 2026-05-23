import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate/models/user_model.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<UserModel> signUpWithProfile({
    required String name,
    required String phone,
    required String duitnowQrBase64,
    required String bankName,
  }) async {
    final uid = _uuid.v4();

    final user = UserModel(
      id: uid,
      name: name,
      phone: phone,
      duitnowQrBase64: duitnowQrBase64,
      bankName: bankName,
      createdAt: Timestamp.now(),
      groupIds: [],
    );

    await _db.collection('users').doc(uid).set(user.toMap());
    return user;
  }

  Future<void> signOut() async {
    // session cleared via SharedPreferences in AuthController
  }
}
