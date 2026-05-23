import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String duitnowQrBase64;
  final String bankName;
  final Timestamp createdAt;
  final List<String> groupIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.duitnowQrBase64,
    required this.bankName,
    required this.createdAt,
    required this.groupIds,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      duitnowQrBase64: map['duitnowQrBase64'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      groupIds: List<String>.from(map['groupIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'duitnowQrBase64': duitnowQrBase64,
        'bankName': bankName,
        'createdAt': createdAt,
        'groupIds': groupIds,
      };

  UserModel copyWith({
    String? name,
    String? phone,
    String? duitnowQrBase64,
    String? bankName,
    List<String>? groupIds,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      duitnowQrBase64: duitnowQrBase64 ?? this.duitnowQrBase64,
      bankName: bankName ?? this.bankName,
      createdAt: createdAt,
      groupIds: groupIds ?? this.groupIds,
    );
  }
}
