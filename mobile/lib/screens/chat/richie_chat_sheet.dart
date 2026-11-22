import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/chat_provider.dart';

class RichieChatSheet extends StatefulWidget {
  final String? initialPrompt;

  const RichieChatSheet({super.key, this.initialPrompt});

  static void show(BuildContext context, {String? initialPrompt}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      showDragHandle: false,
      useSafeArea: true,
      builder: (_) => RichieChatSheet(initialPrompt: initialPrompt),
    );
  }

  @override
  State<RichieChatSheet> createState() => _RichieChatSheetState();
}

class _RichieChatSheetState extends State<RichieChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickPrompts = [
    "💳 Explain my latest alert",
    "🛡️ How do I report fraud?",
    "📊 Summarize my spending",
    "🔒 Tips to keep my cards safe",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage([String? preset]) {
    final text = preset ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (preset == null) {
      _textController.clear();
    }

    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendUserMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.borderSubtle,
                ),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              colors.tealPrimary.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.tealPrimary,
                            size: 22,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Richie",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.tealPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "AI ASSISTANT",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.tealPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "FraudLens Security Copilot",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 20, color: colors.textSecondary),
                      tooltip: "Reset Chat",
                      onPressed: () => chatProvider.clearChat(),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length + (chatProvider.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && chatProvider.isLoading) {
                  return _buildTypingIndicator(colors, theme);
                }
                final msg = messages[index];
                return _buildMessageBubble(msg, colors, theme);
              },
            ),
          ),

          // Quick suggestion chips (if 2 or fewer messages)
          if (messages.length <= 2 && !chatProvider.isLoading)
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ActionChip(
                    label: Text(
                      _quickPrompts[i],
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    backgroundColor: colors.surfaceMuted,
                    side: BorderSide(
                      color: colors.borderSubtle,
                    ),
                    onPressed: () => _sendMessage(_quickPrompts[i]),
                  );
                },
              ),
            ),

          // Input field bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.borderSubtle,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.borderSubtle,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ask Richie anything about your transactions...",
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.tealPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                      onPressed: chatProvider.isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, AppColors colors, ThemeData theme) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.tealPrimary.withValues(alpha: 0.18),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.tealPrimary,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? colors.tealPrimary
                    : colors.surfaceMuted,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser
                      ? colors.tealPrimary
                      : colors.borderSubtle,
                ),
              ),
              child: SelectableText(
                msg.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser ? Colors.white : colors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(AppColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.tealPrimary.withValues(alpha: 0.18),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.tealPrimary,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.tealPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Richie is thinking...",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
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
