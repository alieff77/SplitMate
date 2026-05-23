import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate/models/group_model.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<GroupModel> createGroup({
    required String name,
    required String creatorId,
    required String creatorName,
  }) async {
    final ref = _db.collection('groups').doc();
    final group = GroupModel(
      id: ref.id,
      name: name,
      createdBy: creatorId,
      memberIds: [creatorId],
      memberNames: {creatorId: creatorName},
      createdAt: Timestamp.now(),
    );
    await ref.set(group.toMap());
    return group;
  }

  Future<void> addMember({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    await _db.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberNames.$userId': userName,
    });
  }

  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromMap(doc.id, doc.data()!);
  }

  Stream<GroupModel?> watchGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GroupModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<GroupModel>> watchUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => GroupModel.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }
}
