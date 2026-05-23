import 'package:get/get.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/models/message_model.dart';
import 'package:splitmate/services/ai_service.dart';
import 'package:splitmate/services/message_service.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/bill_controller.dart';

class ChatController extends GetxController {
  final MessageService _messageService = MessageService();
  final AiService _aiService = AiService();

  final RxList<MessageModel> messages = <MessageModel>[].obs;
  final RxBool isAiTyping = false.obs;
  final RxString error = ''.obs;
  final RxString pendingAttachmentBase64 = ''.obs;

  AuthController get _auth => Get.find<AuthController>();

  String get groupId => Get.parameters['id'] ?? '';

  @override
  void onInit() {
    super.onInit();
    _watchMessages();
  }

  void _watchMessages() {
    _messageService.watchMessages(groupId).listen((msgs) {
      messages.value = msgs;
    });
  }

  Future<void> sendMessage(String text, GroupModel group) async {
    if (text.trim().isEmpty && pendingAttachmentBase64.value.isEmpty) return;

    final attachment = pendingAttachmentBase64.value.isEmpty
        ? null
        : pendingAttachmentBase64.value;
    pendingAttachmentBase64.value = '';

    // Save user message to Firestore
    await _messageService.sendMessage(
      groupId: groupId,
      userId: _auth.userId,
      userName: _auth.userName,
      role: 'user',
      content: text,
      attachmentBase64: attachment,
    );

    isAiTyping.value = true;
    error.value = '';

    try {
      // Build conversation history for Claude (last 20 messages, text only)
      final history = messages
          .where((m) => m.billDraft == null)
          .take(20)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final result = await _aiService.sendMessage(
        groupId: groupId,
        userId: _auth.userId,
        group: group,
        conversationHistory: history,
        userMessage: text,
        attachmentBase64: attachment,
      );

      // Save assistant response to Firestore
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
        content: 'Sorry, I ran into an error. Please try again.',
      );
    } finally {
      isAiTyping.value = false;
    }
  }

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
