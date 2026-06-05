import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String id;
  final String description;
  final double amount;
  final List<String> assignedToUserIds;

  const BillItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.assignedToUserIds,
  });

  // Parse BillItem from Firestore map
  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      assignedToUserIds: List<String>.from(map['assignedToUserIds'] as List? ?? []),
    );
  }

  // Serialize BillItem to Firestore map
  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'amount': amount,
        'assignedToUserIds': assignedToUserIds,
      };

  // Copy BillItem with optional field overrides
  BillItem copyWith({
    String? description,
    double? amount,
    List<String>? assignedToUserIds,
  }) {
    return BillItem(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      assignedToUserIds: assignedToUserIds ?? this.assignedToUserIds,
    );
  }
}

class BillShare {
  final String userId;
  final double amountOwed;
  final bool isPaid;
  final Timestamp? paidAt;
  final String? markedPaidByUserId;
  final bool confirmedByPayer;

  const BillShare({
    required this.userId,
    required this.amountOwed,
    required this.isPaid,
    required this.paidAt,
    required this.markedPaidByUserId,
    required this.confirmedByPayer,
  });

  // Parse BillShare from Firestore map
  factory BillShare.fromMap(Map<String, dynamic> map) {
    return BillShare(
      userId: map['userId'] as String? ?? '',
      amountOwed: (map['amountOwed'] as num? ?? 0).toDouble(),
      isPaid: map['isPaid'] as bool? ?? false,
      paidAt: map['paidAt'] as Timestamp?,
      markedPaidByUserId: map['markedPaidByUserId'] as String?,
      confirmedByPayer: map['confirmedByPayer'] as bool? ?? false,
    );
  }

  // Serialize BillShare to Firestore map
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'amountOwed': amountOwed,
        'isPaid': isPaid,
        'paidAt': paidAt,
        'markedPaidByUserId': markedPaidByUserId,
        'confirmedByPayer': confirmedByPayer,
      };

  // Copy BillShare with optional field overrides
  BillShare copyWith({
    double? amountOwed,
    bool? isPaid,
    Timestamp? paidAt,
    String? markedPaidByUserId,
    bool? confirmedByPayer,
  }) {
    return BillShare(
      userId: userId,
      amountOwed: amountOwed ?? this.amountOwed,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      markedPaidByUserId: markedPaidByUserId ?? this.markedPaidByUserId,
      confirmedByPayer: confirmedByPayer ?? this.confirmedByPayer,
    );
  }
}

class BillModel {
  final String id;
  final String title;
  final double totalAmount;
  final double subtotal;
  final double taxAmount;
  final double serviceChargeAmount;
  final String paidByUserId;
  final String? receiptImageBase64;
  final Timestamp createdAt;
  final String createdByUserId;
  final String notes;
  final List<BillItem> items;
  final List<BillShare> shares;

  const BillModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.subtotal,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.paidByUserId,
    this.receiptImageBase64,
    required this.createdAt,
    required this.createdByUserId,
    required this.notes,
    required this.items,
    required this.shares,
  });

  // Parse BillModel from Firestore document
  factory BillModel.fromMap(String id, Map<String, dynamic> map) {
    return BillModel(
      id: id,
      title: map['title'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num? ?? 0).toDouble(),
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] as num? ?? 0).toDouble(),
      serviceChargeAmount: (map['serviceChargeAmount'] as num? ?? 0).toDouble(),
      paidByUserId: map['paidByUserId'] as String? ?? '',
      receiptImageBase64: map['receiptImageBase64'] as String?,
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      createdByUserId: map['createdByUserId'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      items: (map['items'] as List? ?? [])
          .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      shares: (map['shares'] as List? ?? [])
          .map((e) => BillShare.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  // Serialize BillModel to Firestore map
  Map<String, dynamic> toMap() => {
        'title': title,
        'totalAmount': totalAmount,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'serviceChargeAmount': serviceChargeAmount,
        'paidByUserId': paidByUserId,
        'receiptImageBase64': receiptImageBase64,
        'createdAt': createdAt,
        'createdByUserId': createdByUserId,
        'notes': notes,
        'items': items.map((e) => e.toMap()).toList(),
        'shares': shares.map((e) => e.toMap()).toList(),
      };

  // Copy BillModel with updated shares list
  BillModel copyWith({List<BillShare>? shares}) {
    return BillModel(
      id: id,
      title: title,
      totalAmount: totalAmount,
      subtotal: subtotal,
      taxAmount: taxAmount,
      serviceChargeAmount: serviceChargeAmount,
      paidByUserId: paidByUserId,
      receiptImageBase64: receiptImageBase64,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
      notes: notes,
      items: items,
      shares: shares ?? this.shares,
    );
  }
}

class BillDraft {
  final String title;
  final double totalAmount;
  final double subtotal;
  final double taxAmount;
  final double serviceChargeAmount;
  final String paidByUserId;
  final String notes;
  final List<BillItem> items;
  final List<BillShare> shares;
  final DateTime? date; // optional custom date/time for the bill

  const BillDraft({
    required this.title,
    required this.totalAmount,
    required this.subtotal,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.paidByUserId,
    required this.notes,
    required this.items,
    required this.shares,
    this.date,
  });

  // Parse BillDraft from AI response map
  factory BillDraft.fromMap(Map<String, dynamic> map) {
    DateTime? date;
    final rawDate = map['date'];
    if (rawDate is Timestamp) date = rawDate.toDate();

    return BillDraft(
      title: map['title'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num? ?? 0).toDouble(),
      subtotal: (map['subtotal'] as num? ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] as num? ?? 0).toDouble(),
      serviceChargeAmount: (map['serviceChargeAmount'] as num? ?? 0).toDouble(),
      paidByUserId: map['paidByUserId'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      items: (map['items'] as List? ?? [])
          .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      shares: (map['shares'] as List? ?? [])
          .map((e) => BillShare.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      date: date,
    );
  }

  // Serialize BillDraft to map
  Map<String, dynamic> toMap() => {
        'title': title,
        'totalAmount': totalAmount,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'serviceChargeAmount': serviceChargeAmount,
        'paidByUserId': paidByUserId,
        'notes': notes,
        'items': items.map((e) => e.toMap()).toList(),
        'shares': shares.map((e) => e.toMap()).toList(),
        if (date != null) 'date': Timestamp.fromDate(date!),
      };
}
