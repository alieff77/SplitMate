import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/services/bill_service.dart';

class AiChatResult {
  final String content;
  final BillDraft? billDraft;

  const AiChatResult({required this.content, this.billDraft});
}

class AiService {
  final BillService _billService = BillService();

  static const _model = 'gemini-1.5-flash';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent?key=$_apiKey';

  static const _systemPrompt =
      'You are the SplitMate assistant — a friendly helper for a group bill-splitting app. '
      'Users may write in English, Malay, or mixed (rojak). Always respond in a friendly, casual tone. '
      'You help users: check unpaid bills, check balances, create bill drafts from descriptions. '
      'Always use Malaysian Ringgit format: RM 12.50. '
      'When creating a bill draft, ALWAYS confirm before saving — never auto-save. '
      'When you call a tool, use the result to give a helpful, conversational response.';

  static const List<Map<String, dynamic>> _functionDeclarations = [
    {
      'name': 'query_unpaid_bills',
      'description': 'Get unpaid bills for the current user in this group.',
      'parameters': {
        'type': 'object',
        'properties': {
          'userId': {'type': 'string'},
          'groupId': {'type': 'string'},
        },
        'required': ['userId', 'groupId'],
      },
    },
    {
      'name': 'query_balance',
      'description':
          'Compute net balance between the current user and all other group members.',
      'parameters': {
        'type': 'object',
        'properties': {
          'userId': {'type': 'string'},
          'groupId': {'type': 'string'},
        },
        'required': ['userId', 'groupId'],
      },
    },
    {
      'name': 'create_bill_draft',
      'description':
          'Parse a natural-language bill description and return a structured draft for user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'groupId': {'type': 'string'},
          'title': {'type': 'string'},
          'paidByName': {
            'type': 'string',
            'description': 'Name of person who paid',
          },
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'description': {'type': 'string'},
                'amount': {'type': 'number'},
                'assignedToNames': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
            },
          },
          'taxPercent': {'type': 'number'},
          'serviceChargePercent': {'type': 'number'},
          'notes': {'type': 'string'},
        },
        'required': ['groupId', 'title', 'paidByName', 'items'],
      },
    },
  ];

  Future<AiChatResult> sendMessage({
    required String groupId,
    required String userId,
    required GroupModel group,
    required List<Map<String, dynamic>> conversationHistory,
    required String userMessage,
    String? attachmentBase64,
  }) async {
    // Convert history to Gemini format (role: user/model)
    final contents = <Map<String, dynamic>>[];
    for (final msg in conversationHistory) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg['content'] as String? ?? ''},
        ],
      });
    }

    // Add current user message
    if (attachmentBase64 != null) {
      final base64Data = attachmentBase64.contains(',')
          ? attachmentBase64.split(',').last
          : attachmentBase64;
      contents.add({
        'role': 'user',
        'parts': [
          {
            'inlineData': {
              'mimeType': 'image/jpeg',
              'data': base64Data,
            },
          },
          {'text': userMessage.isEmpty ? 'Parse this receipt.' : userMessage},
        ],
      });
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      });
    }

    final response = await _callGemini(contents);
    final candidate = (response['candidates'] as List).first;
    final parts = candidate['content']['parts'] as List;

    // Check for function call
    final fnCallPart = parts.firstWhere(
      (p) => p['functionCall'] != null,
      orElse: () => null,
    );

    if (fnCallPart != null) {
      final fnCall = fnCallPart['functionCall'] as Map<String, dynamic>;
      final toolName = fnCall['name'] as String;
      final toolInput = Map<String, dynamic>.from(fnCall['args'] as Map);

      final toolResult = await _executeTool(
        toolName: toolName,
        input: toolInput,
        group: group,
        currentUserId: userId,
      );

      // Append model turn + tool result, then get final response
      contents.add({'role': 'model', 'parts': parts});
      contents.add({
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': toolName,
              'response': {'result': json.encode(toolResult['data'])},
            },
          },
        ],
      });

      final finalResponse = await _callGemini(contents);
      final finalParts =
          (finalResponse['candidates'] as List).first['content']['parts']
              as List;
      final finalText = _extractText(finalParts);

      return AiChatResult(
        content: finalText,
        billDraft: toolResult['billDraft'] as BillDraft?,
      );
    }

    return AiChatResult(content: _extractText(parts));
  }

  Future<Map<String, dynamic>> _callGemini(
    List<Map<String, dynamic>> contents,
  ) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'content-type': 'application/json'},
      body: json.encode({
        'systemInstruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': contents,
        'tools': [
          {'functionDeclarations': _functionDeclarations},
        ],
        'generationConfig': {'maxOutputTokens': 1024},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI request failed: ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _executeTool({
    required String toolName,
    required Map<String, dynamic> input,
    required GroupModel group,
    required String currentUserId,
  }) async {
    switch (toolName) {
      case 'query_unpaid_bills':
        return _queryUnpaidBills(
          userId: input['userId'] as String,
          groupId: input['groupId'] as String,
        );
      case 'query_balance':
        return _queryBalance(
          userId: input['userId'] as String,
          groupId: input['groupId'] as String,
          group: group,
        );
      case 'create_bill_draft':
        return _createBillDraft(input: input, group: group);
      default:
        return {'data': 'Unknown tool: $toolName'};
    }
  }

  Future<Map<String, dynamic>> _queryUnpaidBills({
    required String userId,
    required String groupId,
  }) async {
    final bills = await _billService.getBills(groupId);
    final unpaid = <Map<String, dynamic>>[];

    for (final bill in bills) {
      for (final share in bill.shares) {
        if (share.userId == userId && !share.isPaid) {
          unpaid.add({
            'billId': bill.id,
            'title': bill.title,
            'amountOwed': share.amountOwed,
            'paidByUserId': bill.paidByUserId,
            'daysAgo': DateTime.now()
                .difference(bill.createdAt.toDate())
                .inDays,
          });
        }
      }
    }

    return {'data': unpaid};
  }

  Future<Map<String, dynamic>> _queryBalance({
    required String userId,
    required String groupId,
    required GroupModel group,
  }) async {
    final bills = await _billService.getBills(groupId);
    final Map<String, double> netBalances = {};

    for (final bill in bills) {
      for (final share in bill.shares) {
        if (share.isPaid) continue;
        if (share.userId == userId && bill.paidByUserId != userId) {
          netBalances[bill.paidByUserId] =
              (netBalances[bill.paidByUserId] ?? 0) - share.amountOwed;
        } else if (bill.paidByUserId == userId && share.userId != userId) {
          netBalances[share.userId] =
              (netBalances[share.userId] ?? 0) + share.amountOwed;
        }
      }
    }

    final result = netBalances.entries
        .map((e) => {
              'userId': e.key,
              'userName': group.memberNames[e.key] ?? e.key,
              'amount': e.value,
            })
        .toList();

    return {'data': result};
  }

  Future<Map<String, dynamic>> _createBillDraft({
    required Map<String, dynamic> input,
    required GroupModel group,
  }) async {
    String? resolveNameToId(String name) {
      final lower = name.toLowerCase().trim();
      for (final entry in group.memberNames.entries) {
        if (entry.value.toLowerCase().contains(lower) ||
            lower.contains(entry.value.toLowerCase())) {
          return entry.key;
        }
      }
      return null;
    }

    final paidByName = input['paidByName'] as String? ?? '';
    final paidByUserId = resolveNameToId(paidByName) ?? '';

    final rawItems = input['items'] as List? ?? [];
    final items = <BillItem>[];
    double subtotal = 0;

    for (int i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i] as Map<String, dynamic>;
      final assignedNames =
          List<String>.from(raw['assignedToNames'] as List? ?? []);
      final assignedIds =
          assignedNames.map(resolveNameToId).whereType<String>().toList();

      final amount = (raw['amount'] as num? ?? 0).toDouble();
      subtotal += amount;

      items.add(BillItem(
        id: 'item_$i',
        description: raw['description'] as String? ?? '',
        amount: amount,
        assignedToUserIds: assignedIds,
      ));
    }

    final taxPercent = (input['taxPercent'] as num? ?? 0).toDouble();
    final servicePercent =
        (input['serviceChargePercent'] as num? ?? 0).toDouble();
    final taxAmount = (subtotal * taxPercent / 100 * 100).round() / 100;
    final serviceAmount =
        (subtotal * servicePercent / 100 * 100).round() / 100;
    final total = subtotal + taxAmount + serviceAmount;

    final Map<String, double> userSubtotals = {};
    for (final item in items) {
      if (item.assignedToUserIds.isEmpty) continue;
      final per = item.amount / item.assignedToUserIds.length;
      for (final uid in item.assignedToUserIds) {
        userSubtotals[uid] = (userSubtotals[uid] ?? 0) + per;
      }
    }

    final shares = userSubtotals.entries.map((e) {
      final prop = subtotal > 0 ? e.value / subtotal : 0.0;
      final userTax = (taxAmount * prop * 100).round() / 100;
      final userService = (serviceAmount * prop * 100).round() / 100;
      return BillShare(
        userId: e.key,
        amountOwed: (e.value + userTax + userService * 100).round() / 100,
        isPaid: false,
        paidAt: null,
        markedPaidByUserId: null,
        confirmedByPayer: false,
      );
    }).toList();

    final draft = BillDraft(
      title: input['title'] as String? ?? 'Bill',
      totalAmount: total,
      subtotal: subtotal,
      taxAmount: taxAmount,
      serviceChargeAmount: serviceAmount,
      paidByUserId: paidByUserId,
      notes: input['notes'] as String? ?? '',
      items: items,
      shares: shares,
    );

    return {
      'data': {
        'title': draft.title,
        'total': total,
        'paidBy': paidByName,
        'itemCount': items.length,
        'resolved': paidByUserId.isNotEmpty,
      },
      'billDraft': draft,
    };
  }

  String _extractText(List parts) {
    return parts
        .where((p) => p['text'] != null)
        .map((p) => p['text'] as String)
        .join('\n')
        .trim();
  }
}
