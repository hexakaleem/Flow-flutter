import 'package:flutter/material.dart';

import '../services/customer_support_service.dart';

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final CustomerSupportService _service = CustomerSupportService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<SupportChatMessage> _messages = [
    const SupportChatMessage(
      role: 'assistant',
      content:
          'Hi driver. Ask me anything about loads, shipments, navigation, fuel logs, or FLOW app tasks.',
    ),
  ];

  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetMessage]) async {
    final messageText = (presetMessage ?? _messageController.text).trim();
    if (messageText.isEmpty) {
      return;
    }

    if (!_isSupportTopic(messageText)) {
      setState(() {
        _messages.add(
          const SupportChatMessage(
            role: 'assistant',
            content:
                'I can only help with FLOW app and trucking topics like loads, shipments, navigation, fuel logs, and vehicle setup.',
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    final userMessage = SupportChatMessage(role: 'user', content: messageText);
    setState(() {
      _messages.add(userMessage);
      _sending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final history = List<SupportChatMessage>.from(_messages)..removeLast();
      final response = await _service.sendMessage(
        history: history,
        userMessage: messageText,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(SupportChatMessage(role: 'assistant', content: response));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          SupportChatMessage(
            role: 'assistant',
            content:
                'I could not reach the support service. Please try again later.\n\n$error',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isSupportTopic(String message) {
    final text = message.toLowerCase();
    const keywords = [
      'load',
      'loads',
      'shipment',
      'shipments',
      'booking',
      'book',
      'pickup',
      'delivery',
      'destination',
      'origin',
      'navigation',
      'navigate',
      'route',
      'fuel',
      'log',
      'vehicle',
      'profile',
      'registration',
      'truck',
      'eta',
      'load board',
    ];

    return keywords.any(text.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 350,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFC07BFE),
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header pill ──────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1128),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Text(
                            'Customer Support',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _messages.length <= 1
                              ? null
                              : () {
                                  setState(() {
                                    _messages
                                      ..clear()
                                      ..add(
                                        const SupportChatMessage(
                                          role: 'assistant',
                                          content:
                                              'Hi driver. Ask me anything about loads, shipments, navigation, fuel logs, or FLOW app tasks.',
                                        ),
                                      );
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Quick chips ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _QuickChip(
                            label: 'How do I book a load?',
                            onTap: () => _sendMessage('How do I book a load?')),
                        _QuickChip(
                            label: 'How do I start navigation?',
                            onTap: () =>
                                _sendMessage('How do I start navigation?')),
                        _QuickChip(
                            label: 'Where is my shipment?',
                            onTap: () => _sendMessage('Where is my shipment?')),
                        _QuickChip(
                            label: 'How do I log fuel?',
                            onTap: () => _sendMessage('How do I log fuel?')),
                      ],
                    ),
                  ),
                ),
                // ── Chat list ────────────────────────────────────────
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _messages.length) {
                          return const _TypingBubble();
                        }

                        final message = _messages[index];
                        final isUser = message.role == 'user';
                        return _ChatBubble(
                          text: message.content,
                          isUser: isUser,
                        );
                      },
                    ),
                  ),
                ),
                // ── Input bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Ask about loads, navigation...',
                            hintStyle:
                                const TextStyle(color: Colors.black38),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 17),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 54,
                        width: 54,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8A30FA),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
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

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final background =
        isUser ? const Color(0xFF1E1128) : const Color(0xFFF4F1FF);
    final foreground = isUser ? Colors.white : Colors.black87;

    return Container(
      alignment: alignment,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(color: foreground, height: 1.35),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Typing...',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
