import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final Timestamp createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    required this.memberNames,
    required this.createdAt,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      memberNames: Map<String, String>.from(
        (map['memberNames'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdBy': createdBy,
        'memberIds': memberIds,
        'memberNames': memberNames,
        'createdAt': createdAt,
      };

  GroupModel copyWith({
    String? name,
    List<String>? memberIds,
    Map<String, String>? memberNames,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      createdAt: createdAt,
    );
  }
}
