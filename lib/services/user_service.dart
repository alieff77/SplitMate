import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate/models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Stream<UserModel?> watchUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<void> addGroupToUser(String userId, String groupId) async {
    await _db.collection('users').doc(userId).update({
      'groupIds': FieldValue.arrayUnion([groupId]),
    });
  }
}
