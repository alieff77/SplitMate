import 'package:get/get.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/models/message_model.dart';
import 'package:splitmate/services/ai_service.dart';
import 'package:splitmate/services/message_service.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/bill_controller.dart';

class ChatController extends GetxController {
  // Service dependencies
  final MessageService _messageService = MessageService();
  final AiService _aiService = AiService();

  // Observable state
  final RxList<MessageModel> messages = <MessageModel>[].obs;
  final RxBool isAiTyping = false.obs;
  final RxString error = ''.obs;

  // Auth controller accessor
  AuthController get _auth => Get.find<AuthController>();

  // Current group ID from route params
  String get groupId => Get.parameters['id'] ?? '';

  // Subscribe to message stream on controller init
  @override
  void onInit() {
    super.onInit();
    _watchMessages();
  }

  // Listen for realtime message updates from Firestore
  void _watchMessages() {
    _messageService.watchMessages(groupId).listen((msgs) {
      messages.value = msgs;
    });
  }

  // Send user message then get and post AI response
  Future<void> sendMessage(String text, GroupModel group) async {
    if (text.trim().isEmpty) return;

    await _messageService.sendMessage(
      groupId: groupId,
      userId: _auth.userId,
      userName: _auth.userName,
      role: 'user',
      content: text,
    );

    isAiTyping.value = true;
    error.value = '';

    try {
      final history = messages
          .where((m) => m.billDraft == null)
          .take(20)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final result = await _aiService.sendMessage(
        groupId: groupId,
        userId: _auth.userId,
        currentUserName: _auth.userName,
        group: group,
        conversationHistory: history,
        userMessage: text,
      );

      await _messageService.sendMessage(
        groupId: groupId,
        userId: 'assistant',
        userName: 'SplitMate AI',
        role: 'assistant',
        content: result.content,
        billDraft: result.billDraft,
      );
    } catch (e) {
      error.value = 'AI error: ${e.toString()}';
      await _messageService.sendMessage(
        groupId: groupId,
        userId: 'assistant',
        userName: 'SplitMate AI',
        role: 'assistant',
        content: 'Error: ${e.toString()}',
      );
    } finally {
      isAiTyping.value = false;
    }
  }

  // Save AI bill draft to Firestore and notify chat
  Future<void> confirmBillDraft(BillDraft draft) async {
    final billCtrl = Get.find<BillController>();
    try {
      await billCtrl.submitBillDraft(groupId, draft);
      await _messageService.sendMessage(
        groupId: groupId,
        userId: 'assistant',
        userName: 'SplitMate AI',
        role: 'assistant',
        content: '✅ Bill "${draft.title}" saved! Everyone can see it in the Bills tab.',
      );
    } catch (e) {
      error.value = e.toString();
    }
  }
}
