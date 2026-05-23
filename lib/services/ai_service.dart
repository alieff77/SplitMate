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

  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-5';

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  static const _systemPrompt = '''
You are the SplitMate assistant — a friendly helper for a group bill-splitting app.
Users may write in English, Malay, or mixed (rojak). Always respond in a friendly, casual tone.
You help users: check unpaid bills, check balances, create bill drafts from descriptions.
Always use Malaysian Ringgit format: RM 12.50.
When creating a bill draft, ALWAYS confirm before saving — never auto-save.
When you call a tool, use the result to give a helpful, conversational response.
''';

  // Tool definitions for Claude
  static const List<Map<String, dynamic>> _tools = [
    {
      'name': 'query_unpaid_bills',
      'description': 'Get unpaid bills for the current user in this group.',
      'input_schema': {
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
      'input_schema': {
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
      'input_schema': {
        'type': 'object',
        'properties': {
          'groupId': {'type': 'string'},
          'title': {'type': 'string'},
          'paidByName': {'type': 'string', 'description': 'Name of person who paid'},
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
    final messages = List<Map<String, dynamic>>.from(conversationHistory);

    // Add user message
    if (attachmentBase64 != null) {
      final base64Data = attachmentBase64.contains(',')
          ? attachmentBase64.split(',').last
          : attachmentBase64;
      messages.add({
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': 'image/jpeg',
              'data': base64Data,
            },
          },
          {'type': 'text', 'text': userMessage},
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': userMessage});
    }

    final response = await _callClaude(messages);

    // Handle tool use
    if (response['stop_reason'] == 'tool_use') {
      final toolUseBlock = (response['content'] as List)
          .firstWhere((b) => b['type'] == 'tool_use');
      final toolName = toolUseBlock['name'] as String;
      final toolInput = toolUseBlock['input'] as Map<String, dynamic>;

      final toolResult = await _executeTool(
        toolName: toolName,
        input: toolInput,
        group: group,
        currentUserId: userId,
      );

      // Send tool result back
      messages.add({'role': 'assistant', 'content': response['content']});
      messages.add({
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': toolUseBlock['id'],
            'content': json.encode(toolResult['data']),
          },
        ],
      });

      final finalResponse = await _callClaude(messages);
      final finalText = _extractText(finalResponse['content'] as List);

      return AiChatResult(
        content: finalText,
        billDraft: toolResult['billDraft'] as BillDraft?,
      );
    }

    return AiChatResult(content: _extractText(response['content'] as List));
  }

  Future<Map<String, dynamic>> _callClaude(
      List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: json.encode({
        'model': _model,
        'max_tokens': 1024,
        'system': _systemPrompt,
        'tools': _tools,
        'messages': messages,
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
          // Current user owes paidBy person
          netBalances[bill.paidByUserId] =
              (netBalances[bill.paidByUserId] ?? 0) - share.amountOwed;
        } else if (bill.paidByUserId == userId && share.userId != userId) {
          // Others owe current user
          netBalances[share.userId] =
              (netBalances[share.userId] ?? 0) + share.amountOwed;
        }
      }
    }

    final result = netBalances.entries.map((e) => {
          'userId': e.key,
          'userName': group.memberNames[e.key] ?? e.key,
          'amount': e.value, // positive = they owe you, negative = you owe them
        }).toList();

    return {'data': result};
  }

  Future<Map<String, dynamic>> _createBillDraft({
    required Map<String, dynamic> input,
    required GroupModel group,
  }) async {
    // Resolve member names to IDs
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
      final assignedNames = List<String>.from(raw['assignedToNames'] as List? ?? []);
      final assignedIds = assignedNames
          .map(resolveNameToId)
          .whereType<String>()
          .toList();

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

    // Build shares
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

  String _extractText(List content) {
    return content
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n')
        .trim();
  }
}
