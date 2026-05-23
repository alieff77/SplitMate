import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate/models/bill_model.dart';

class BillService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _billsRef(String groupId) =>
      _db.collection('groups').doc(groupId).collection('bills');

  Future<BillModel> createBill(String groupId, BillModel bill) async {
    final ref = _billsRef(groupId).doc();
    final newBill = BillModel(
      id: ref.id,
      title: bill.title,
      totalAmount: bill.totalAmount,
      subtotal: bill.subtotal,
      taxAmount: bill.taxAmount,
      serviceChargeAmount: bill.serviceChargeAmount,
      paidByUserId: bill.paidByUserId,
      receiptImageBase64: bill.receiptImageBase64,
      createdAt: Timestamp.now(),
      createdByUserId: bill.createdByUserId,
      notes: bill.notes,
      items: bill.items,
      shares: bill.shares,
    );
    await ref.set(newBill.toMap());
    return newBill;
  }

  Stream<List<BillModel>> watchBills(String groupId) {
    return _billsRef(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BillModel.fromMap(d.id, d.data())).toList());
  }

  Future<List<BillModel>> getBills(String groupId) async {
    final snap = await _billsRef(groupId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => BillModel.fromMap(d.id, d.data())).toList();
  }

  Future<BillModel?> getBill(String groupId, String billId) async {
    final doc = await _billsRef(groupId).doc(billId).get();
    if (!doc.exists) return null;
    return BillModel.fromMap(doc.id, doc.data()!);
  }

  Stream<BillModel?> watchBill(String groupId, String billId) {
    return _billsRef(groupId).doc(billId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BillModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> markSharePaid({
    required String groupId,
    required String billId,
    required String userId,
    required bool confirmedByPayer,
  }) async {
    final doc = await _billsRef(groupId).doc(billId).get();
    if (!doc.exists) return;

    final bill = BillModel.fromMap(doc.id, doc.data()!);
    final updatedShares = bill.shares.map((s) {
      if (s.userId == userId) {
        return s.copyWith(
          isPaid: true,
          paidAt: Timestamp.now(),
          confirmedByPayer: confirmedByPayer,
        );
      }
      return s;
    }).toList();

    await _billsRef(groupId).doc(billId).update({
      'shares': updatedShares.map((s) => s.toMap()).toList(),
    });
  }

  Future<void> confirmShareReceived({
    required String groupId,
    required String billId,
    required String userId,
    required String confirmedByUserId,
  }) async {
    final doc = await _billsRef(groupId).doc(billId).get();
    if (!doc.exists) return;

    final bill = BillModel.fromMap(doc.id, doc.data()!);
    final updatedShares = bill.shares.map((s) {
      if (s.userId == userId) {
        return s.copyWith(
          confirmedByPayer: true,
          markedPaidByUserId: confirmedByUserId,
        );
      }
      return s;
    }).toList();

    await _billsRef(groupId).doc(billId).update({
      'shares': updatedShares.map((s) => s.toMap()).toList(),
    });
  }
}
