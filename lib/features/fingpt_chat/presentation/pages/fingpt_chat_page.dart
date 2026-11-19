import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/category_taxonomy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/finku_app_bar.dart';
import '../../../shared_wallet/presentation/providers/wallet_provider.dart';
import '../../data/fingpt_service.dart';
import '../../domain/models/fingpt_response.dart';

class _ChatMessage {
  _ChatMessage({
    required this.isUser,
    required this.timestampLabel,
    this.text,
    this.aiResponse,
  });

  final bool isUser;
  final String timestampLabel;
  final String? text;
  final FinGptResponse? aiResponse;
  bool isSaved = false;
}

/// Halaman FinGPT Asisten Keuangan sesuai Stitch `FinGPT Chat Asisten Keuangan` (`FR-AI-01..04`).
class FinGptChatPage extends ConsumerStatefulWidget {
  const FinGptChatPage({
    super.key,
    required this.avatarInitials,
    required this.onOpenSettings,
    this.avatarUrl,
  });

  final String avatarInitials;
  final String? avatarUrl;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<FinGptChatPage> createState() => _FinGptChatPageState();
}

class _FinGptChatPageState extends ConsumerState<FinGptChatPage> {
  final _finGptService = FinGptService();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        isUser: false,
        timestampLabel: '10:12 WIB',
        text:
            'Halo! Saya FinGPT. Ketik pengeluaranmu dengan bahasa sehari-hari (mis. "Beli bensin 50rb, parkir 2rb, sama jajan kopi 18k pakai OVO"), nanti langsung saya pecah dan kategorikan.',
      ),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _currentTimeLabel() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm WIB';
  }

  Future<void> _sendMessage([String? presetText]) async {
    final raw = (presetText ?? _chatController.text).trim();
    if (raw.isEmpty || _isSending) return;

    _chatController.clear();
    setState(() {
      _isSending = true;
      _messages.add(
        _ChatMessage(
          isUser: true,
          timestampLabel: _currentTimeLabel(),
          text: raw,
        ),
      );
    });
    _scrollToBottom();

    final summary = ref.read(walletProvider).summary;
    final budgetContext =
        'Total pengeluaran bulan ini ${CurrencyNormalizer.formatRupiah(summary.totalSpend)} dari batas ${CurrencyNormalizer.formatRupiah(summary.totalLimit)} (sisa ${CurrencyNormalizer.formatRupiah(summary.remainingBudget)}).';

    final response = await _finGptService.analyzePrompt(
      raw,
      budgetContextSummary: budgetContext,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _messages.add(
        _ChatMessage(
          isUser: false,
          timestampLabel: _currentTimeLabel(),
          text: response.analyticsAnswer ?? response.clarificationMessage,
          aiResponse: response,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _confirmSaveAiTransactions(_ChatMessage msg) async {
    final resp = msg.aiResponse;
    if (resp == null || resp.transactions.isEmpty || msg.isSaved) return;

    final notifier = ref.read(walletProvider.notifier);
    try {
      for (final tx in resp.transactions) {
        await notifier.addTransaction(
          merchantName: '${tx.itemName} (${tx.walletName})',
          category: tx.category,
          amount: tx.amount,
          source: 'ai_chat',
          txDate: DateTime.tryParse(tx.txDate) ?? DateTime(2026, 11, 18),
        );
      }
      if (!mounted) return;
      setState(() {
        msg.isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${resp.transactions.length} transaksi (${CurrencyNormalizer.formatRupiah(resp.totalAmount)}) berhasil dicatat!',
          ),
          backgroundColor: FinkuColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkuColors.surface,
      appBar: FinkuTopAppBar(
        avatarInitials: widget.avatarInitials,
        avatarUrl: widget.avatarUrl,
        onOpenSettings: widget.onOpenSettings,
      ),
      body: Column(
        children: [
          // Top AI Status Banner & Quick Prompts
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: FinkuColors.surface.withValues(alpha: 0.96),
              border: const Border(
                bottom: BorderSide(color: FinkuColors.borderSubtle),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: FinkuColors.primaryFixed.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: FinkuColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FinGPT Asisten',
                              style: FinkuTypography.headlineSm(),
                            ),
                            Text(
                              'Natural Language Expense Logger',
                              style: FinkuTypography.labelSm(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FinkuColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: FinkuColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Aktif',
                            style: FinkuTypography.labelSm(
                              color: FinkuColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickPromptChip(
                        icon: Icons.restaurant_rounded,
                        color: FinkuColors.primary,
                        label: 'Sisa budget makan?',
                        onTap: () => _sendMessage('Sisa budget makan?'),
                      ),
                      _QuickPromptChip(
                        icon: Icons.bar_chart_rounded,
                        color: FinkuColors.secondary,
                        label: 'Ringkasan minggu ini',
                        onTap: () => _sendMessage('Ringkasan minggu ini'),
                      ),
                      _QuickPromptChip(
                        icon: Icons.receipt_long_rounded,
                        color: FinkuColors.primary,
                        label: 'Catat makan siang 35k',
                        onTap: () => _sendMessage('Catat makan siang 35k'),
                      ),
                      _QuickPromptChip(
                        icon: Icons.bolt_rounded,
                        color: FinkuColors.secondary,
                        label: 'Bensin 50rb, parkir 2rb, kopi 18k OVO',
                        onTap: () => _sendMessage(
                          'Beli bensin 50rb, parkir 2rb, sama jajan kopi 18k pakai OVO',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.isUser) {
                  return _UserBubble(msg: msg);
                }
                return _AiBubble(
                  msg: msg,
                  onQuickReply: (text) => _sendMessage(text),
                  onConfirmSave: () => _confirmSaveAiTransactions(msg),
                );
              },
            ),
          ),

          // Sticky Chat Bar (`input_fingpt_chat` & `btn_send_fingpt`)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: FinkuColors.borderSubtle)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    _chatController.text = 'Bayar galon air 20rb tunai';
                  },
                  icon: const Icon(Icons.mic_rounded),
                  color: FinkuColors.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    backgroundColor: FinkuColors.surfaceContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    identifier: 'input_fingpt_chat',
                    textField: true,
                    child: TextField(
                      key: const Key('input_fingpt_chat'),
                      controller: _chatController,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ketik pengeluaranmu... (cth: makan 25rb)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9999),
                          borderSide: const BorderSide(
                            color: FinkuColors.borderSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9999),
                          borderSide: const BorderSide(
                            color: FinkuColors.borderSubtle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  identifier: 'btn_send_fingpt',
                  button: true,
                  label: 'Kirim Pesan',
                  child: Material(
                    key: const Key('btn_send_fingpt'),
                    color: FinkuColors.primaryBrand,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isSending ? null : () => _sendMessage(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(label, style: FinkuTypography.labelMd()),
        backgroundColor: FinkuColors.surfaceContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        onPressed: onTap,
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.msg});

  final _ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  color: FinkuColors.inverseSurface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Text(
                  msg.text ?? '',
                  style: FinkuTypography.bodyMd(
                    color: FinkuColors.inverseOnSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(msg.timestampLabel, style: FinkuTypography.labelSm()),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: FinkuColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({
    required this.msg,
    required this.onQuickReply,
    required this.onConfirmSave,
  });

  final _ChatMessage msg;
  final void Function(String text) onQuickReply;
  final VoidCallback onConfirmSave;

  @override
  Widget build(BuildContext context) {
    final resp = msg.aiResponse;
    final hasTransactions = resp != null && resp.transactions.isNotEmpty;
    final needsClarify = resp != null && resp.needsClarification;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: FinkuColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTransactions)
                  Semantics(
                    identifier: 'card_ai_confirmation',
                    container: true,
                    child: Container(
                      key: const Key('card_ai_confirmation'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FinkuColors.surfaceContainerLowest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: FinkuColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.smart_toy_rounded,
                                    size: 17,
                                    color: FinkuColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'FinGPT Intelligence',
                                    style: FinkuTypography.labelMd(
                                      color: FinkuColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${resp.responseTimeMs} ms',
                                style: FinkuTypography.labelSm(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Siap, ${resp.transactions.length} transaksi berhasil dideteksi! Mohon periksa rincian berikut:',
                            style: FinkuTypography.bodyMd(),
                          ),
                          const SizedBox(height: 10),
                          ...resp.transactions.map((tx) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: FinkuColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: FinkuColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CategoryTaxonomy.iconFor(tx.category),
                                      color: FinkuColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.itemName,
                                          style: FinkuTypography.titleMd(),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    FinkuColors.surfaceVariant,
                                                borderRadius:
                                                    BorderRadius.circular(9999),
                                              ),
                                              child: Text(
                                                tx.category,
                                                style: FinkuTypography.labelSm(
                                                  color: FinkuColors.secondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ${tx.walletName}',
                                              style: FinkuTypography.labelSm(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyNormalizer.formatRupiah(tx.amount),
                                    style: FinkuTypography.titleMd(),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Pengeluaran',
                                style: FinkuTypography.labelMd(),
                              ),
                              Text(
                                CurrencyNormalizer.formatRupiah(
                                  resp.totalAmount,
                                ),
                                style: FinkuTypography.headlineSm(
                                  color: FinkuColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (msg.isSaved)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: FinkuColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: FinkuColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tersimpan & Tersinkronisasi',
                                    style: FinkuTypography.labelMd(
                                      color: FinkuColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Semantics(
                              identifier: 'btn_confirm_ai_tx',
                              button: true,
                              child: SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  key: const Key('btn_confirm_ai_tx'),
                                  onPressed: onConfirmSave,
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Simpan (${CurrencyNormalizer.formatRupiah(resp.totalAmount)})',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FinkuColors.surfaceContainerLowest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(color: FinkuColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text ?? '',
                          style: FinkuTypography.bodyMd(),
                        ),
                        if (needsClarify) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _QuickReplyPill(
                                label: 'Listrik PLN 150rb',
                                onTap: () => onQuickReply('Listrik PLN 150rb'),
                              ),
                              _QuickReplyPill(
                                label: 'Internet WiFi 280rb',
                                onTap: () =>
                                    onQuickReply('Internet WiFi 280rb'),
                              ),
                              _QuickReplyPill(
                                label: 'PDAM 45rb',
                                onTap: () => onQuickReply('PDAM 45rb'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(msg.timestampLabel, style: FinkuTypography.labelSm()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyPill extends StatelessWidget {
  const _QuickReplyPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: FinkuTypography.labelSm()),
      backgroundColor: FinkuColors.surfaceContainer,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}
