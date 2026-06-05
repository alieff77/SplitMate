import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/services/bill_service.dart';
import 'package:splitmate/services/message_service.dart';
import 'package:splitmate/services/user_service.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/core/utils/bill_calculator.dart';
import 'package:uuid/uuid.dart';

class BillController extends GetxController {
  // Service dependencies
  final BillService _billService = BillService();
  final MessageService _messageService = MessageService();
  final UserService _userService = UserService();
  final _uuid = const Uuid();

  // Loading and error state
  final RxBool isSubmitting = false.obs;
  final RxString error = ''.obs;

  // Form state for create bill
  final RxString title = ''.obs;
  final RxString paidByUserId = ''.obs;
  final RxList<BillItem> items = <BillItem>[].obs;
  final RxDouble taxPercent = 0.0.obs;
  final RxDouble serviceChargePercent = 0.0.obs;
  final RxString notes = ''.obs;
  final RxString receiptBase64 = ''.obs;

  // Auth controller accessor
  AuthController get _auth => Get.find<AuthController>();

  // Current group ID from route params
  String get groupId => Get.parameters['id'] ?? '';

  // Add empty item to bill
  void addItem() {
    items.add(BillItem(
      id: _uuid.v4(),
      description: '',
      amount: 0,
      assignedToUserIds: [],
    ));
  }

  // Remove item by index
  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
    }
  }

  // Replace item at given index with updated version
  void updateItem(int index, BillItem updated) {
    if (index >= 0 && index < items.length) {
      items[index] = updated;
    }
  }

  // Recalculate bill totals from current items and tax/service rates
  BillCalculationResult get calculation => BillCalculator.calculate(
        items: items,
        taxPercent: taxPercent.value,
        serviceChargePercent: serviceChargePercent.value,
      );

  // Submit bill form to Firestore and navigate back
  Future<void> submitBill() async {
    isSubmitting.value = true;
    error.value = '';
    try {
      final calc = calculation;
      final bill = BillModel(
        id: '',
        title: title.value,
        totalAmount: calc.totalAmount,
        subtotal: calc.subtotal,
        taxAmount: calc.taxAmount,
        serviceChargeAmount: calc.serviceChargeAmount,
        paidByUserId: paidByUserId.value,
        receiptImageBase64:
            receiptBase64.value.isEmpty ? null : receiptBase64.value,
        createdAt: Timestamp.now(),
        createdByUserId: _auth.userId,
        notes: notes.value,
        items: items.toList(),
        shares: calc.shares,
      );
      await _billService.createBill(groupId, bill);
      _resetForm();
      Get.back();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isSubmitting.value = false;
    }
  }

  // Save AI-generated draft bill to Firestore
  Future<void> submitBillDraft(String groupId, BillDraft draft) async {
    isSubmitting.value = true;
    error.value = '';
    try {
      final bill = BillModel(
        id: '',
        title: draft.title,
        totalAmount: draft.totalAmount,
        subtotal: draft.subtotal,
        taxAmount: draft.taxAmount,
        serviceChargeAmount: draft.serviceChargeAmount,
        paidByUserId: draft.paidByUserId,
        receiptImageBase64: null,
        createdAt: draft.date != null
            ? Timestamp.fromDate(draft.date!)
            : Timestamp.now(),
        createdByUserId: _auth.userId,
        notes: draft.notes,
        items: draft.items,
        shares: draft.shares,
      );
      await _billService.createBill(groupId, bill);
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  // Mark current user's share as paid and post notification to chat
  Future<void> markSharePaid({
    required String groupId,
    required String billId,
    required String payerName,
    required double amount,
  }) async {
    final userId = _auth.userId;
    await _billService.markSharePaid(
      groupId: groupId,
      billId: billId,
      userId: userId,
      confirmedByPayer: false,
    );
    await _messageService.sendMessage(
      groupId: groupId,
      userId: userId,
      userName: _auth.userName,
      role: 'user',
      content:
          '${_auth.userName} says they paid RM ${amount.toStringAsFixed(2)} to $payerName.',
    );
  }

  // Payer confirms they received payment from debtor
  Future<void> confirmReceived({
    required String groupId,
    required String billId,
    required String debtorId,
  }) async {
    await _billService.confirmShareReceived(
      groupId: groupId,
      billId: billId,
      userId: debtorId,
      confirmedByUserId: _auth.userId,
    );
  }

  // Fetch DuitNow QR base64 for the payer
  Future<String?> getPayerQr(String payerUserId) async {
    final user = await _userService.getUser(payerUserId);
    return user?.duitnowQrBase64;
  }

  // Clear all form fields after successful submission
  void _resetForm() {
    title.value = '';
    paidByUserId.value = '';
    items.clear();
    taxPercent.value = 0;
    serviceChargePercent.value = 0;
    notes.value = '';
    receiptBase64.value = '';
  }
}
