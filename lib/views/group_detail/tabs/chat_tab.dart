import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitmate/controllers/auth_controller.dart';
import 'package:splitmate/controllers/bill_controller.dart';
import 'package:splitmate/controllers/chat_controller.dart';
import 'package:splitmate/controllers/group_detail_controller.dart';
import 'package:splitmate/core/constants/app_colors.dart';
import 'package:splitmate/core/utils/image_utils.dart';
import 'package:splitmate/widgets/bill_draft_card.dart';
import 'package:splitmate/widgets/chat_message_widget.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final ChatController _chat = Get.find<ChatController>();
  final AuthController _auth = Get.find<AuthController>();
  final GroupDetailController _groupCtrl = Get.find<GroupDetailController>();
  final BillController _billCtrl = Get.find<BillController>();

  @override
  void initState() {
    super.initState();
    _chat.messages.listen((_) => _scrollToBottom());
    // Anti-drama: warn about old unpaid bills
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOldBills());
  }

  void _checkOldBills() {
    if (_groupCtrl.hasOldUnpaidBills) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ You have unpaid bills older than 7 days. Check the Bills tab!'),
              backgroundColor: AppColors.pending,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _chat.pendingAttachmentBase64.value.isEmpty) return;
    final group = _groupCtrl.group.value;
    if (group == null) return;
    _msgCtrl.clear();
    _chat.sendMessage(text, group);
  }

  Future<void> _attachImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final base64 = await ImageUtils.compressAndEncode(picked);
      _chat.pendingAttachmentBase64.value = base64;
      Get.snackbar('Image attached',
          'Describe it in the text box, then send.',
          backgroundColor: AppColors.successLight,
          colorText: AppColors.success,
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Obx(() {
            final messages = _chat.messages;

            if (messages.isEmpty && !_chat.isAiTyping.value) {
              return ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                children: [
                  _DummyBubble(isMe: true, text: 'semalam makan McD, aku bayar RM45'),
                  _DummyBubble(isMe: false, text: 'Ok! I\'ve parsed your McD bill. Total RM45, paid by you. Should I create this bill for your group?'),
                  _DummyBubble(isMe: true, text: 'yes'),
                  _DummyBubble(isMe: false, text: '✅ Done! Bill \'McD Malam Malam\' saved for RM45. Everyone in MCD can see it in the Bills tab.'),
                ],
              );
            }

            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              itemCount:
                  messages.length + (_chat.isAiTyping.value ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == messages.length) {
                  return const TypingIndicator();
                }
                final msg = messages[i];
                final isMe = msg.userId == _auth.userId;

                Widget? draftCard;
                if (msg.billDraft != null) {
                  draftCard = Obx(() => BillDraftCard(
                        draft: msg.billDraft!,
                        memberNames:
                            _groupCtrl.group.value?.memberNames ?? {},
                        isLoading: _billCtrl.isSubmitting.value,
                        onConfirm: () =>
                            _chat.confirmBillDraft(msg.billDraft!),
                        onDiscard: () {},
                      ));
                }

                return ChatMessageWidget(
                  message: msg,
                  isMe: isMe,
                  draftCard: draftCard,
                );
              },
            );
          }),
        ),

        // Attachment preview
        Obx(() {
          if (_chat.pendingAttachmentBase64.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            color: AppColors.successLight,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.image, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Image attached',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.success))),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.success),
                  onPressed: () =>
                      _chat.pendingAttachmentBase64.value = '',
                ),
              ],
            ),
          );
        }),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: AppColors.textSecondary),
                  onPressed: _attachImage,
                  tooltip: 'Attach receipt',
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ask anything, or describe a bill...',
                      hintStyle: const TextStyle(fontSize: 14),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => GestureDetector(
                      onTap: _chat.isAiTyping.value ? null : _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _chat.isAiTyping.value
                              ? AppColors.border
                              : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send,
                            color: Colors.white, size: 20),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DummyBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  const _DummyBubble({required this.isMe, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Text('AI',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary
                    : const Color(0xFFf0fdf4),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: !isMe
                    ? Border.all(color: AppColors.successLight)
                    : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
