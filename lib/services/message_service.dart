import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate/models/message_model.dart';

class MessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _db.collection('groups').doc(groupId).collection('messages');

  Stream<List<MessageModel>> watchMessages(String groupId) {
    return _messagesRef(groupId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.id, d.data())).toList());
  }

  Future<MessageModel> sendMessage({
    required String groupId,
    required String userId,
    required String userName,
    required String role,
    required String content,
    String? attachmentBase64,
    String? parsedBillId,
    dynamic billDraft,
  }) async {
    final ref = _messagesRef(groupId).doc();
    final msg = MessageModel(
      id: ref.id,
      userId: userId,
      userName: userName,
      role: role,
      content: content,
      attachmentBase64: attachmentBase64,
      parsedBillId: parsedBillId,
      createdAt: Timestamp.now(),
      billDraft: billDraft,
    );
    await ref.set(msg.toMap());
    return msg;
  }
}
