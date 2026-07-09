import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/copilot_engine.dart';
import '../state/providers.dart';

class _Msg {
  final String text;
  final bool fromUser;
  final List<String> bullets;
  _Msg(this.text, {this.fromUser = false, this.bullets = const []});
}

class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _controller = TextEditingController();
  final _engine = const CopilotEngine();
  final List<_Msg> _messages = [
    _Msg("Hi! I'm your Wedding Copilot. Ask me what to do next, what you're "
        "missing, or how to optimise your budget."),
  ];

  static const _suggestions = [
    'What should I do next?',
    'Am I missing anything?',
    'Optimise my budget',
    'Suggest honeymoon destinations',
    'Vendor payments?',
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final roadmap = ref.read(roadmapProvider).valueOrNull;
    setState(() => _messages.add(_Msg(text, fromUser: true)));
    _controller.clear();

    if (roadmap == null) {
      setState(() => _messages.add(_Msg('Still building your roadmap — try again in a moment.')));
      return;
    }
    final reply = _engine.respond(
      text,
      roadmap: roadmap,
      profile: ref.read(profileProvider),
      budget: ref.read(budgetProvider),
      vendors: ref.read(vendorsProvider),
    );
    setState(() => _messages.add(_Msg(reply.headline, bullets: reply.lines)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('Wedding Copilot'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[_messages.length - 1 - i], theme),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Ask your Copilot…',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(_controller.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, ThemeData theme) {
    final align = m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = m.fromUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = m.fromUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.text, style: TextStyle(color: textColor, fontWeight: m.fromUser ? FontWeight.w500 : FontWeight.w600)),
              if (m.bullets.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final b in m.bullets)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(b, style: TextStyle(color: textColor, fontSize: 13)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
