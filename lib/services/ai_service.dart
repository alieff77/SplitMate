import 'package:splitmate/models/bill_model.dart';
import 'package:splitmate/models/group_model.dart';
import 'package:splitmate/services/bill_service.dart';

class AiChatResult {
  final String content;
  final BillDraft? billDraft;

  const AiChatResult({required this.content, this.billDraft});
}

enum _Intent { balance, whoOwesMe, bills, createBill, greeting, help, unknown }

class _ParsedItem {
  final String id;
  final String description;
  final double amount;
  final List<String> assignedToUserIds;

  const _ParsedItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.assignedToUserIds,
  });
}

class AiService {
  final BillService _billService = BillService();

  // ─── Entry point ──────────────────────────────────────────────────────────

  Future<AiChatResult> sendMessage({
    required String groupId,
    required String userId,
    required String currentUserName,
    required GroupModel group,
    required List<Map<String, dynamic>> conversationHistory,
    required String userMessage,
  }) async {
    final lower = userMessage.toLowerCase().trim();
    final intent = _detectIntent(lower);

    switch (intent) {
      case _Intent.balance:
        return _handleBalance(groupId, userId, group);
      case _Intent.whoOwesMe:
        return _handleWhoOwesMe(groupId, userId, group);
      case _Intent.bills:
        return _handleBills(groupId, userId, group);
      case _Intent.createBill:
        return _handleCreateBill(userMessage, userId, currentUserName, group);
      case _Intent.greeting:
        return AiChatResult(
          content: 'Hey ${currentUserName.split(' ').first}! 👋 Nak check hutang, tambah bill, atau tanya balance? Taip "help" untuk tengok semua yang aku boleh buat.',
        );
      case _Intent.help:
        return AiChatResult(content: _helpText());
      default:
        return AiChatResult(content: _unknownResponse());
    }
  }

  // ─── Intent Detection ─────────────────────────────────────────────────────

  _Intent _detectIntent(String lower) {
    if (_any(lower, [
      'berapa hutang', 'hutang berapa', 'berapa aku hutang', 'aku hutang',
      'berapa lagi aku', 'berapa kena bayar', 'berapa lagi kena',
      'berapa saya hutang', 'saya hutang', 'check balance', 'balance aku',
      'i owe', 'how much owe', 'how much do i', 'i still owe',
      'berapa lagi belum bayar', 'berapa yg aku', 'belum bayar berapa',
      'aku belum bayar', 'aku xbayar', 'hutang aku berapa', 'aku owe',
      'aku ada hutang', 'aku still hutang', 'still belum settle',
      'brp hutang', 'bape hutang', 'bpe hutang', 'total hutang',
    ])) { return _Intent.balance; }

    if (_any(lower, [
      'siapa hutang', 'sapa hutang', 'who owes', 'owe me',
      'siapa belum bayar', 'orang hutang aku', 'hutang dengan aku',
      'siapa kena bayar aku', 'bayar aku balik', 'owing me',
      'siapa yang hutang', 'sapa yang hutang', 'sapa owe',
      'diorang hutang', 'dorang hutang', 'dia hutang aku',
      'sape hutang', 'korang hutang',
    ])) { return _Intent.whoOwesMe; }

    if (_any(lower, [
      'list hutang', 'senarai hutang', 'list bill', 'my bill',
      'hutang apa', 'bill apa', 'unpaid bill', 'belum settle',
      'what bill', 'apa hutang', 'show bill', 'semua hutang', 'senarai bill',
      'tunjuk hutang', 'tunjuk bill', 'semak bill',
      'makan apa', 'aku makan apa', 'dah makan apa', 'pergi mana',
      'aku beli apa', 'apa yg aku', 'apa bill', 'bill aku',
    ])) { return _Intent.bills; }

    if (_any(lower, [
      ' hi ', 'hello', ' hey ', ' hai ', 'halo', 'assalam', 'salam',
      'morning', 'selamat pagi', 'selamat petang', 'selamat malam',
      'sup ', 'yo ', 'waddup', 'wassup', 'apa khabar', 'camne',
    ])) { return _Intent.greeting; }

    if (_any(lower, [
      'help', 'tolong', 'bantuan', 'what can you', 'apa boleh',
      'cara guna', 'how to use', 'arahan', 'command', 'boleh buat apa',
      'macam mana guna', 'mcm mana guna', 'contoh', 'tutorial',
    ])) { return _Intent.help; }

    // Bill creation: any RM amount, or number + food/pay keyword
    final hasRm = RegExp(r'rm\s*\d|\d+\s*(?:ringgit|hengget|ingget)').hasMatch(lower);
    final hasNum = RegExp(r'\d+(?:\.\d+)?').hasMatch(lower);
    final hasBillContext = _any(lower, [
      // Payment verbs
      'bayar', 'paid', 'belanja', 'belanje', 'sponsor', 'tanggung',
      'cover', 'keluarkan', 'settle', 'split',
      // Eating
      'makan', 'mkn', 'lunch', 'dinner', 'breakfast', 'supper', 'minum',
      'tapau', 'order', 'lepak', 'jajan', 'singgah', 'sarapan', 'brunch',
      'makan malam', 'makan tengahari', 'makan pagi',
      // Food items
      'nasi', 'ayam', 'ikan', 'mee', 'mi ', 'roti', 'kopi', 'teh', 'air ',
      'burger', 'pizza', 'sushi', 'laksa', 'boba', 'bubble',
      'goreng', 'lemak', 'rendang', 'satay', 'kuih', 'set ', 'combo',
      'char kuey', 'kuey teow', 'wantan', 'dim sum', 'bihun',
      // Popular places
      'mcd', 'mcdonalds', "mcdonald", 'kfc', 'subway', 'dominos',
      'pizza hut', 'tealive', 'chatime', 'starbucks', 'oldtown',
      'mamak', 'warung', 'kedai', 'restoran', 'cafe', 'kopitiam',
      "nandos", "nando", 'sushi king', 'seoul garden', 'shabu',
      'secret recipe', 'mydin', 'tesco', 'aeon', 'giant', 'lotus',
      // Transport
      'petrol', 'minyak', 'parking', 'grab', 'gojek', 'toll',
      'teksi', 'taxi', 'lrt', 'mrt', 'bus', 'bas', 'komuter', 'rapidkl',
      // Shopping/others
      'beli', 'buy', 'shopping', 'barang', 'groceri', 'grocery',
      'market', 'pasar', 'mini market', 'convenient',
      // Tax/charges (standalone bill mention)
      'tax', 'cukai', 'gst', 'sst', 'service charge', 'servis',
    ]);
    if (hasRm || (hasNum && hasBillContext)) return _Intent.createBill;

    return _Intent.unknown;
  }

  bool _any(String text, List<String> kw) => kw.any((k) => text.contains(k));

  // ─── Balance: detailed per-bill breakdown ─────────────────────────────────

  Future<AiChatResult> _handleBalance(
      String groupId, String userId, GroupModel group) async {
    try {
      final bills = await _billService.getBills(groupId);

      // Per-person, collect each individual bill detail
      final Map<String, List<Map<String, dynamic>>> iOweBills = {};
      final Map<String, List<Map<String, dynamic>>> theyOweBills = {};

      for (final bill in bills) {
        for (final share in bill.shares) {
          if (share.isPaid) continue;

          final days = DateTime.now()
              .difference(bill.createdAt.toDate())
              .inDays;
          final dayStr = days == 0
              ? 'hari ni'
              : days == 1
                  ? 'semalam'
                  : '$days hari lepas';

          final itemDescs = bill.items
              .map((i) => i.description)
              .where((d) => d.isNotEmpty)
              .toList();

          if (share.userId == userId && bill.paidByUserId != userId) {
            (iOweBills[bill.paidByUserId] ??= []).add({
              'title': bill.title,
              'amount': share.amountOwed,
              'dayStr': dayStr,
              'items': itemDescs,
            });
          } else if (bill.paidByUserId == userId && share.userId != userId) {
            (theyOweBills[share.userId] ??= []).add({
              'title': bill.title,
              'amount': share.amountOwed,
              'dayStr': dayStr,
              'items': itemDescs,
            });
          }
        }
      }

      if (iOweBills.isEmpty && theyOweBills.isEmpty) {
        return const AiChatResult(
            content: 'Semua settled! Takde hutang dalam group ni. 🎉');
      }

      final buf = StringBuffer();

      if (iOweBills.isNotEmpty) {
        buf.writeln('💸 Kau hutang:\n');
        double grandTotal = 0;
        for (final entry in iOweBills.entries) {
          final name = group.memberNames[entry.key] ?? entry.key;
          final personTotal =
              entry.value.fold(0.0, (s, b) => s + (b['amount'] as double));
          grandTotal += personTotal;
          buf.writeln(
              '  $name — RM ${personTotal.toStringAsFixed(2)}');
          for (final b in entry.value) {
            final items = b['items'] as List<String>;
            buf.writeln(
                '    • ${b['title']} (${b['dayStr']}): RM ${(b['amount'] as double).toStringAsFixed(2)}');
            if (items.isNotEmpty) {
              buf.writeln('      Items: ${items.join(', ')}');
            }
          }
          buf.writeln();
        }
        buf.writeln('  Total kau kena bayar: RM ${grandTotal.toStringAsFixed(2)}');
        if (theyOweBills.isNotEmpty) buf.writeln();
      }

      if (theyOweBills.isNotEmpty) {
        buf.writeln('💰 Orang hutang kau (bayaran asing):\n');
        double grandTotal = 0;
        for (final entry in theyOweBills.entries) {
          final name = group.memberNames[entry.key] ?? entry.key;
          final personTotal =
              entry.value.fold(0.0, (s, b) => s + (b['amount'] as double));
          grandTotal += personTotal;
          buf.writeln('  $name — RM ${personTotal.toStringAsFixed(2)}');
          for (final b in entry.value) {
            final items = b['items'] as List<String>;
            buf.writeln(
                '    • ${b['title']} (${b['dayStr']}): RM ${(b['amount'] as double).toStringAsFixed(2)}');
            if (items.isNotEmpty) {
              buf.writeln('      Items: ${items.join(', ')}');
            }
          }
          buf.writeln();
        }
        buf.writeln('  Total orang kena bayar kau: RM ${grandTotal.toStringAsFixed(2)}');
      }

      return AiChatResult(content: buf.toString().trim());
    } catch (e) {
      return AiChatResult(content: 'Ada error: $e');
    }
  }

  // ─── Who owes me (detailed) ───────────────────────────────────────────────

  Future<AiChatResult> _handleWhoOwesMe(
      String groupId, String userId, GroupModel group) async {
    try {
      final bills = await _billService.getBills(groupId);
      final Map<String, List<Map<String, dynamic>>> debtorBills = {};

      for (final bill in bills) {
        if (bill.paidByUserId != userId) continue;
        for (final share in bill.shares) {
          if (share.isPaid || share.userId == userId) continue;
          final days = DateTime.now()
              .difference(bill.createdAt.toDate())
              .inDays;
          final dayStr = days == 0
              ? 'hari ni'
              : days == 1
                  ? 'semalam'
                  : '$days hari lepas';
          final itemDescs = bill.items
              .map((i) => i.description)
              .where((d) => d.isNotEmpty)
              .toList();
          (debtorBills[share.userId] ??= []).add({
            'title': bill.title,
            'amount': share.amountOwed,
            'dayStr': dayStr,
            'items': itemDescs,
          });
        }
      }

      if (debtorBills.isEmpty) {
        return const AiChatResult(
            content: 'Tiada sesiapa yang hutang kau sekarang. 👍');
      }

      final buf = StringBuffer('💰 Orang yang hutang kau:\n\n');
      double grand = 0;
      for (final entry in debtorBills.entries) {
        final name = group.memberNames[entry.key] ?? entry.key;
        final personTotal =
            entry.value.fold(0.0, (s, b) => s + (b['amount'] as double));
        grand += personTotal;
        buf.writeln('  $name — RM ${personTotal.toStringAsFixed(2)}');
        for (final b in entry.value) {
          final items = b['items'] as List<String>;
          buf.writeln(
              '    • ${b['title']} (${b['dayStr']}): RM ${(b['amount'] as double).toStringAsFixed(2)}');
          if (items.isNotEmpty) {
            buf.writeln('      Items: ${items.join(', ')}');
          }
        }
        buf.writeln();
      }
      buf.write('  Total: RM ${grand.toStringAsFixed(2)}');

      return AiChatResult(content: buf.toString().trim());
    } catch (e) {
      return AiChatResult(content: 'Ada error: $e');
    }
  }

  // ─── My unpaid bills (detailed) ──────────────────────────────────────────

  Future<AiChatResult> _handleBills(
      String groupId, String userId, GroupModel group) async {
    try {
      final bills = await _billService.getBills(groupId);
      final unpaid = <Map<String, dynamic>>[];

      for (final bill in bills) {
        for (final share in bill.shares) {
          if (share.userId == userId && !share.isPaid) {
            final days = DateTime.now()
                .difference(bill.createdAt.toDate())
                .inDays;
            final dayStr = days == 0
                ? 'hari ni'
                : days == 1
                    ? 'semalam'
                    : '$days hari lepas';
            final itemDescs = bill.items
                .map((i) => i.description)
                .where((d) => d.isNotEmpty)
                .toList();
            unpaid.add({
              'title': bill.title,
              'amount': share.amountOwed,
              'paidBy': group.memberNames[bill.paidByUserId] ??
                  bill.paidByUserId,
              'dayStr': dayStr,
              'items': itemDescs,
            });
          }
        }
      }

      if (unpaid.isEmpty) {
        return const AiChatResult(
            content: 'Takde bills yang belum bayar. Kau clear! 🎉');
      }

      final buf = StringBuffer('📋 Bills kau yang belum settle:\n\n');
      double total = 0;
      for (final b in unpaid) {
        final amt = b['amount'] as double;
        final items = b['items'] as List<String>;
        total += amt;
        buf.writeln('  • ${b['title']} — RM ${amt.toStringAsFixed(2)}');
        if (items.isNotEmpty) {
          buf.writeln('    Items: ${items.join(', ')}');
        }
        buf.writeln('    Bayar kepada: ${b['paidBy']} (${b['dayStr']})');
        buf.writeln();
      }
      buf.write('Total kena bayar: RM ${total.toStringAsFixed(2)}');

      return AiChatResult(content: buf.toString().trim());
    } catch (e) {
      return AiChatResult(content: 'Ada error: $e');
    }
  }

  // ─── Create bill (local NLP) ──────────────────────────────────────────────

  Future<AiChatResult> _handleCreateBill(
      String text, String userId, String currentUserName, GroupModel group) async {
    final draft = _parseBill(text, userId, currentUserName, group);
    if (draft == null) {
      return AiChatResult(content:
        'Hmm, tak dapat detect amount. Cuba tulis mcm ni:\n\n'
        '• "Makan KFC RM45, aku bayar untuk aku dan Ali"\n'
        '• "Tapau McD, ayam spicy RM12 aku, McFlurry RM8 Akmal"\n'
        '• "Dinner Nandos RM80 dengan Amin dan Zara, tax rm5"\n'
        '• "Lunch RM63, aku rm33, akmal rm30, tax 6%"\n'
        '• "Petrol PLUS RM80, semua split, service charge 10%"'
      );
    }
    return AiChatResult(
      content: 'Ok! Dah parse bill kau 📝 Semak details kat bawah, edit kalau ada salah, pastu tekan Save Bill:',
      billDraft: draft,
    );
  }


  // ─── Local NLP bill parser ────────────────────────────────────────────────

  BillDraft? _parseBill(
      String text, String userId, String currentUserName, GroupModel group) {
    final lower = text.toLowerCase();

    double? grandTotal;
    final totalMatch = RegExp(
      r'(?:total|jumlah|harga total)\b.{0,25}?rm\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (totalMatch != null) {
      grandTotal = double.tryParse(totalMatch.group(1)!);
    }

    final mentionsTax = _any(lower, ['tax', 'cukai', 'selebihnya', 'remainder']);
    final mentionsService = _any(lower, [
      'service charge', 'service fee', 'servis', 'khidmat', 'sc ', 'svc ',
    ]);

    // Explicit RM amounts: "tax rm15", "tax 15", "cukai rm5", "sc rm3"
    double? explicitTax;
    double? explicitService;
    final taxAmtMatch = RegExp(
      r'(?:tax|cukai|gst|sst)\s*(?:rm\s*)?(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (taxAmtMatch != null) {
      explicitTax = double.tryParse(taxAmtMatch.group(1)!);
    }
    final svcAmtMatch = RegExp(
      r'(?:service(?:\s*charge)?|servis|svc|sc)\s*(?:rm\s*)?(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (svcAmtMatch != null) {
      explicitService = double.tryParse(svcAmtMatch.group(1)!);
    }

    // Percentage-based: "tax 6%", "sst 8%", "service 10%", "servis 5%"
    double? taxPct;
    double? servicePct;
    final taxPctMatch = RegExp(
      r'(?:tax|cukai|gst|sst)\s*(\d+(?:\.\d+)?)\s*%',
      caseSensitive: false,
    ).firstMatch(lower);
    if (taxPctMatch != null) {
      taxPct = double.tryParse(taxPctMatch.group(1)!);
    }
    final svcPctMatch = RegExp(
      r'(?:service(?:\s*charge)?|servis|svc|sc)\s*(\d+(?:\.\d+)?)\s*%',
      caseSensitive: false,
    ).firstMatch(lower);
    if (svcPctMatch != null) {
      servicePct = double.tryParse(svcPctMatch.group(1)!);
    }

    String paidByUserId = userId;
    for (final entry in group.memberNames.entries) {
      if (entry.key == userId) continue;
      final first = entry.value.split(' ').first.toLowerCase();
      final full = entry.value.toLowerCase();
      if (_nameBeforeVerb(lower, first) || _nameBeforeVerb(lower, full)) {
        paidByUserId = entry.key;
        break;
      }
    }

    final rawSegments = text
        .split(RegExp(r'[.,;!]'))
        .map((s) => s.trim())
        .where((s) => s.length > 2)
        .toList();

    final parsedItems = <_ParsedItem>[];

    for (int i = 0; i < rawSegments.length; i++) {
      final seg = rawSegments[i];
      final segLow = seg.toLowerCase().trim();

      if (segLow.contains('total') || segLow.contains('jumlah') ||
          _any(segLow, ['bayar', 'paid by', 'bayar oleh', 'dibayar']) ||
          _any(segLow, [
            'tax', 'cukai', 'selebihnya', 'service charge', 'servis',
            'termasuk', 'including', 'incl',
          ])) {
        continue;
      }

      final amtMatch =
          RegExp(r'rm\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false)
              .firstMatch(segLow);
      if (amtMatch == null) continue;

      final amount = double.tryParse(amtMatch.group(1)!);
      if (amount == null || amount <= 0) continue;

      final assignedIds = _extractSegmentParticipants(segLow, userId, group);
      final desc = _describeSegment(segLow, amtMatch.group(0)!, group, i);

      parsedItems.add(_ParsedItem(
        id: 'item_$i',
        description: desc,
        amount: amount,
        assignedToUserIds: assignedIds,
      ));
    }

    if (parsedItems.isEmpty) {
      final amount = grandTotal ?? _findFirstAmount(lower);
      if (amount == null) return null;

      final isPerPerson = _any(lower, [
        'sorang', 'seorang', 'per person', 'per head',
        'each', 'tiap orang', 'each person', 'setiap',
      ]);
      final participants = _extractParticipants(lower, userId, group);
      final total =
          isPerPerson && participants.isNotEmpty
              ? double.parse(
                  (amount * participants.length).toStringAsFixed(2))
              : double.parse(amount.toStringAsFixed(2));

      parsedItems.add(_ParsedItem(
        id: 'item_0',
        description: _generateTitle(text, group),
        amount: total,
        assignedToUserIds:
            participants.isEmpty ? group.memberIds : participants,
      ));
      grandTotal ??= total;
    }

    final itemSubtotal = double.parse(
        parsedItems.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(2));
    grandTotal ??= itemSubtotal;

    double taxAmount = 0;
    double serviceAmount = 0;

    // Explicit RM amounts take priority
    if (explicitTax != null) {
      taxAmount = double.parse(explicitTax.toStringAsFixed(2));
    } else if (taxPct != null) {
      taxAmount = double.parse((itemSubtotal * taxPct / 100).toStringAsFixed(2));
    }
    if (explicitService != null) {
      serviceAmount = double.parse(explicitService.toStringAsFixed(2));
    } else if (servicePct != null) {
      serviceAmount = double.parse((itemSubtotal * servicePct / 100).toStringAsFixed(2));
    }

    // If no explicit amounts but grand total > items, derive from difference
    if (explicitTax == null && explicitService == null &&
        grandTotal > itemSubtotal + 0.01) {
      final remaining =
          double.parse((grandTotal - itemSubtotal).toStringAsFixed(2));
      if (mentionsTax && mentionsService) {
        taxAmount = double.parse((remaining / 2).toStringAsFixed(2));
        serviceAmount =
            double.parse((remaining - taxAmount).toStringAsFixed(2));
      } else if (mentionsService) {
        serviceAmount = remaining;
      } else if (mentionsTax) {
        taxAmount = remaining;
      }
    }

    // Recompute grand total to include explicit tax/service
    if (explicitTax != null || explicitService != null) {
      grandTotal = double.parse(
          (itemSubtotal + taxAmount + serviceAmount).toStringAsFixed(2));
    }

    final Map<String, double> userSubtotals = {};
    for (final item in parsedItems) {
      if (item.assignedToUserIds.isEmpty) continue;
      final per = item.amount / item.assignedToUserIds.length;
      for (final uid in item.assignedToUserIds) {
        userSubtotals[uid] = (userSubtotals[uid] ?? 0) + per;
      }
    }

    final shares = userSubtotals.entries.map((e) {
      final prop = itemSubtotal > 0 ? e.value / itemSubtotal : 0.0;
      final uTax = double.parse((taxAmount * prop).toStringAsFixed(2));
      final uSvc = double.parse((serviceAmount * prop).toStringAsFixed(2));
      return BillShare(
        userId: e.key,
        amountOwed:
            double.parse((e.value + uTax + uSvc).toStringAsFixed(2)),
        isPaid: false,
        paidAt: null,
        markedPaidByUserId: null,
        confirmedByPayer: false,
      );
    }).toList();

    return BillDraft(
      title: _generateTitle(text, group),
      totalAmount: grandTotal,
      subtotal: itemSubtotal,
      taxAmount: taxAmount,
      serviceChargeAmount: serviceAmount,
      paidByUserId: paidByUserId,
      notes: '',
      items: parsedItems
          .map((p) => BillItem(
                id: p.id,
                description: p.description,
                amount: p.amount,
                assignedToUserIds: p.assignedToUserIds,
              ))
          .toList(),
      shares: shares,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool _nameBeforeVerb(String text, String name) {
    const verbs = [
      'bayar', 'paid', 'belanja', 'belanje', 'treat', 'cover', 'sponsor'
    ];
    return verbs.any(
        (v) => text.contains('$name $v') || text.contains('$name, $v'));
  }

  double? _findFirstAmount(String lower) {
    final m =
        RegExp(r'rm\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false).firstMatch(lower);
    if (m != null) return double.tryParse(m.group(1)!);
    final m2 = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(lower);
    return m2 != null ? double.tryParse(m2.group(1)!) : null;
  }

  List<String> _extractSegmentParticipants(
      String segLow, String userId, GroupModel group) {
    final result = <String>[];
    if (RegExp(r'\b(aku|saya)\b').hasMatch(segLow)) result.add(userId);
    for (final entry in group.memberNames.entries) {
      if (result.contains(entry.key)) continue;
      final first = entry.value.split(' ').first.toLowerCase();
      final full = entry.value.toLowerCase();
      if (segLow.contains(first) || segLow.contains(full)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  List<String> _extractParticipants(
      String lower, String userId, GroupModel group) {
    if (_any(lower, [
      'semua', 'everyone', 'all of us', 'korang', 'kita semua',
      'semuanya', 'satu group', 'whole group', 'semua orang', 'all of them',
    ])) {
      return List.from(group.memberIds);
    }

    final result = <String>[];
    if (_any(lower, ['aku', 'saya', ' me ', 'myself', ' i '])) {
      result.add(userId);
    }

    bool anyMemberMentioned = false;
    for (final entry in group.memberNames.entries) {
      if (result.contains(entry.key)) continue;
      final first = entry.value.split(' ').first.toLowerCase();
      final full = entry.value.toLowerCase();
      if (lower.contains(first) || lower.contains(full)) {
        result.add(entry.key);
        anyMemberMentioned = true;
      }
    }

    // "dengan [member]" implies current user was there too
    final denganPattern = RegExp(r'\b(dengan|with|bersama)\b');
    if (denganPattern.hasMatch(lower) &&
        anyMemberMentioned &&
        !result.contains(userId)) {
      result.insert(0, userId);
    }

    return result.isEmpty ? List.from(group.memberIds) : result;
  }

  String _describeSegment(
      String segLow, String amountStr, GroupModel group, int idx) {
    var desc = segLow;
    desc = desc.replaceAll(amountStr.toLowerCase(), '');
    for (final entry in group.memberNames.entries) {
      desc = desc.replaceAll(entry.value.toLowerCase(), '');
      desc = desc.replaceAll(entry.value.split(' ').first.toLowerCase(), '');
    }
    desc = desc.replaceAll(
      RegExp(
          r'\b(aku|saya|dia|kau|korang|amik|ambil|ambilkan|order|dapat|'
          r'beli|untuk|dengan|rm|ringgit|je|jer|saja|sahaja|pula|plk|pun|'
          r'juga|lagi|tu|ni|yg|yang|la|lah|dah|nak|ade|ada|tapi|tp|'
          r'jugak|memang|mmg|ok|okay|boleh|bleh)\b'),
      ' ',
    );
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (desc.length < 2) return 'Item ${idx + 1}';
    return desc
        .split(' ')
        .where((w) => w.length > 1)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _generateTitle(String text, GroupModel group) {
    final lower = text.toLowerCase();
    final memberNamesLow =
        group.memberNames.values.map((n) => n.toLowerCase()).toSet();
    final memberFirstNamesLow = group.memberNames.values
        .map((n) => n.split(' ').first.toLowerCase())
        .toSet();

    const skipWords = {
      'the', 'a', 'an', 'dengan', 'dan', 'untuk', 'aku', 'saya',
      'dia', 'korang', 'semua', 'semalam', 'tadi', 'harini', 'hari',
      'sama', 'bersama', 'juga', 'pun', 'je', 'lah', 'la',
      'total', 'jumlah', 'bill', 'belanja',
    };
    const locPrefixes = {'kt', 'kat', 'ke', 'di', 'dekat', 'near', 'at'};
    const triggers = [
      'makan ', 'lunch ', 'dinner ', 'breakfast ', 'sarapan ', 'supper ',
      'kat ', 'kt ', 'at ', 'dekat ', '@ ', 'beli ', 'buy ', 'minum ',
      'petrol ', 'parking ', 'grab ',
    ];

    for (final trigger in triggers) {
      final idx = lower.indexOf(trigger);
      if (idx == -1) continue;
      var after = text.substring(idx + trigger.length).trim();
      var afterLow = after.toLowerCase();

      if (!locPrefixes.contains(trigger.trim())) {
        for (final prefix in locPrefixes) {
          if (afterLow.startsWith('$prefix ')) {
            after = after.substring(prefix.length + 1).trim();
            afterLow = afterLow.substring(prefix.length + 1).trim();
            break;
          }
        }
      }

      final capMatch =
          RegExp(r'([A-Z][a-zA-Z&]+(?:\s+[A-Z][a-zA-Z&]+)*)').firstMatch(after);
      if (capMatch != null) {
        final candidate = capMatch.group(1)!.trim();
        if (!memberNamesLow.contains(candidate.toLowerCase()) &&
            !skipWords.contains(candidate.toLowerCase()) &&
            candidate.length > 1) {
          return candidate;
        }
      }

      final anyMatch = RegExp(r'^([a-zA-Z][a-zA-Z&]*)').firstMatch(after);
      if (anyMatch != null) {
        final word = anyMatch.group(1)!;
        final wordLow = word.toLowerCase();
        if (!skipWords.contains(wordLow) &&
            !locPrefixes.contains(wordLow) &&
            !memberNamesLow.contains(wordLow) &&
            !memberFirstNamesLow.contains(wordLow)) {
          if (word == wordLow && word.length <= 5) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1);
        }
      }
    }

    const skipSet = {'I', 'RM', 'Ok', 'OK', 'No', 'Ya', 'Yes', 'Aku', 'Saya'};
    for (final word in text.split(RegExp(r'\s+'))) {
      final clean = word.replaceAll(RegExp(r'[,;.!?]'), '');
      if (clean.length > 2 &&
          clean[0] == clean[0].toUpperCase() &&
          clean[0] != clean[0].toLowerCase() &&
          !skipSet.contains(clean) &&
          !memberNamesLow.contains(clean.toLowerCase()) &&
          !memberFirstNamesLow.contains(clean.toLowerCase()) &&
          !RegExp(r'^\d').hasMatch(clean)) {
        return clean;
      }
    }

    const fallbacks = {
      'petrol': 'Petrol', 'parking': 'Parking', 'grab': 'Grab',
      'toll': 'Toll', 'grocery': 'Grocery', 'barang': 'Grocery',
      'makan': 'Makan', 'lunch': 'Lunch', 'dinner': 'Dinner',
      'breakfast': 'Breakfast', 'sarapan': 'Sarapan', 'supper': 'Supper',
      'kopi': 'Kopi', 'teh': 'Teh Tarik', 'boba': 'Boba',
      'movie': 'Movie', 'wayang': 'Movie', 'shopping': 'Shopping',
      'minum': 'Drinks',
    };
    for (final entry in fallbacks.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    return 'Shared Expense';
  }

  // ─── Static responses ─────────────────────────────────────────────────────

  String _helpText() =>
      'Aku boleh buat benda ni:\n\n'
      '💰 Check balance:\n'
      '  "berapa aku hutang?"\n'
      '  "brp lagi aku kena bayar?"\n'
      '  "siapa hutang aku?"\n\n'
      '📋 List bills:\n'
      '  "aku makan apa?" / "list hutang aku"\n'
      '  "bill apa belum bayar?"\n\n'
      '➕ Tambah bill baru (describe je):\n'
      '  "Makan KFC RM45, aku bayar untuk aku dan Ali"\n'
      '  "Tapau McD, ayam spicy RM12 aku, McFlurry RM8 Akmal"\n'
      '  "Dinner Nandos RM80 dengan Amin dan Zara, tax rm5"\n'
      '  "Lunch RM63, aku rm33, akmal rm30, tax 6%"\n'
      '  "Petrol PLUS RM80, semua split, service charge 10%"\n'
      '  "Kopi RM8 sorang, ada 3 orang"\n'
      '  "Grab RM15, aku dan Bob"\n\n'
      'Boleh guna BM, English, atau campur! 🇲🇾';

  String _unknownResponse() =>
      'Hmm, aku tak faham tu. Cuba tanya pasal balance, hutang, atau describe bill baru.\n\n'
      'Taip "help" untuk tengok contoh. 😊';
}
