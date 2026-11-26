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
    'Explain my latest alert',
    'How do I report fraud?',
    'Summarize my spending',
    'Tips to keep my accounts safe',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty) {
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
          duration: const Duration(milliseconds: 220),
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
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final availableHeight = (media.size.height - bottomInset - 24).clamp(
      240.0,
      media.size.height * 0.86,
    );

    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: availableHeight,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: colors.border),
            left: BorderSide(color: colors.border),
            right: BorderSide(color: colors.border),
          ),
        ),
        child: Column(
          children: [
            // Drag handle & Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.borderSubtle)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.tealPrimary.withValues(
                          alpha: 0.14,
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: colors.tealPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Richie',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Fraud & spending assistant',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        tooltip: 'New conversation',
                        onPressed: () => chatProvider.clearChat(),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        tooltip: 'Close',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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

            // Quick suggestions
            if (messages.length <= 2 && !chatProvider.isLoading)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return ActionChip(
                      label: Text(
                        _quickPrompts[i],
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: colors.surfaceMuted,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: () => _sendMessage(_quickPrompts[i]),
                    );
                  },
                ),
              ),

            // Clean Input Bar (no double border inside pill)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.border),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Ask Richie...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textMuted,
                              fontSize: 14,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: colors.tealPrimary,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: colors.isDark
                              ? const Color(0xFF0F0F11)
                              : Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Send',
                        onPressed: chatProvider.isLoading
                            ? null
                            : () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, AppColors colors, ThemeData theme) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: colors.tealPrimary.withValues(alpha: 0.14),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: colors.tealPrimary,
                size: 13,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? colors.tealPrimary : colors.surfaceMuted,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: SelectableText(
                msg.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? (colors.isDark ? const Color(0xFF0F0F11) : Colors.white)
                      : colors.textPrimary,
                  fontSize: 13.5,
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
            radius: 13,
            backgroundColor: colors.tealPrimary.withValues(alpha: 0.14),
            child: Icon(
              Icons.chat_bubble_rounded,
              color: colors.tealPrimary,
              size: 13,
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
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.tealPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Richie is thinking...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
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
