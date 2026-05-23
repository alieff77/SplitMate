import 'package:cloud_firestore/cloud_firestore.dart';
import 'bill_model.dart';

class MessageModel {
  final String id;
  final String userId;
  final String userName;
  final String role; // 'user' | 'assistant'
  final String content;
  final String? attachmentBase64;
  final String? parsedBillId;
  final Timestamp createdAt;
  final BillDraft? billDraft;

  const MessageModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.content,
    this.attachmentBase64,
    this.parsedBillId,
    required this.createdAt,
    this.billDraft,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      content: map['content'] as String? ?? '',
      attachmentBase64: map['attachmentBase64'] as String?,
      parsedBillId: map['parsedBillId'] as String?,
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      billDraft: map['billDraft'] != null
          ? BillDraft.fromMap(Map<String, dynamic>.from(map['billDraft'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'role': role,
        'content': content,
        'attachmentBase64': attachmentBase64,
        'parsedBillId': parsedBillId,
        'createdAt': createdAt,
        'billDraft': billDraft?.toMap(),
      };
}

class BalanceEntry {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;

  const BalanceEntry({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
  });
}
