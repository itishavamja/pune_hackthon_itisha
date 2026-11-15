import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/chips.dart';
import '../../widgets/typing_dots.dart';

class _Msg {
  _Msg.user(this.text)
      : isUser = true,
        source = null,
        isError = false,
        needsAnalysis = false;
  _Msg.bot(this.text, {this.source, this.isError = false, this.needsAnalysis = false}) : isUser = false;

  final bool isUser;
  final String text;
  final String? source; // "ai" | "fallback"
  final bool isError, needsAnalysis;
}

class AskSheet extends ConsumerStatefulWidget {
  const AskSheet({super.key});

  @override
  ConsumerState<AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<AskSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _sending = false;

  static const _suggestions = [
    'Why are my sales decreasing?',
    'Which customers are likely to stop visiting?',
    'How can I improve weekend sales?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send(String raw) async {
    final q = raw.trim();
    if (q.length < 3 || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg.user(q));
      _sending = true;
    });
    _toBottom();
    try {
      final r = await ref.read(apiClientProvider).ask(q, ref.read(languageProvider));
      _messages.add(_Msg.bot(r.answer, source: r.source));
    } on ApiException catch (e) {
      _messages.add(e.isConflict
          ? _Msg.bot('I need your latest numbers first. Run the AI analysis, then ask me again.', needsAnalysis: true)
          : _Msg.bot(e.message, isError: true));
    }
    if (!mounted) return;
    setState(() => _sending = false);
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(gradient: Brand.ctaGradient, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask Dukaan360', style: context.tt.titleLarge),
                    Text('Answers use only your own data', style: TextStyle(color: context.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in const ['Hindi', 'Marathi', 'English'])
                FilterPill(
                  label: l,
                  selected: lang == l,
                  onTap: () {
                    ref.read(languageProvider.notifier).state = l;
                    ref.read(sharedPrefsProvider).setString(kPrefLanguage, l);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _messages.isEmpty
              ? _Suggestions(onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) return const _TypingBubble();
                    return _Bubble(msg: _messages[i]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(hintText: 'Ask about your shop…', counterText: ''),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(_input.text),
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      children: [
        Text('Try asking', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        for (var i = 0; i < _AskSheetState._suggestions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onPick(_AskSheetState._suggestions[i]),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cs.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.cs.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 19, color: context.cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_AskSheetState._suggestions[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Icon(Icons.north_east_rounded, size: 16, color: context.muted),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: (i * 90).ms, duration: 350.ms)
                .slideY(begin: 0.15, end: 0, delay: (i * 90).ms),
          ),
      ],
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = msg.isUser;
    final bg = user
        ? context.cs.primary
        : (msg.isError ? Brand.danger.withValues(alpha: 0.12) : context.cardColor);
    final fg = user ? (context.dark ? Brand.navy : Colors.white) : context.cs.onSurface;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: bg,
        border: user ? null : Border.all(color: context.hairline),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 4),
          bottomRight: Radius.circular(user ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.5)),
          if (msg.needsAnalysis) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 40)),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(navIndexProvider.notifier).state = 3;
              },
              child: const Text('Go to AI analysis'),
            ),
          ],
          if (msg.source != null) ...[
            const SizedBox(height: 8),
            msg.source == 'ai'
                ? const Pill('Sarvam AI', color: Brand.primary, icon: Icons.auto_awesome_rounded)
                : const Pill('From your data', color: Brand.info, icon: Icons.analytics_rounded),
          ],
        ],
      ),
    );

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: bubble),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.12, end: 0, duration: 280.ms, curve: Curves.easeOutCubic);
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: context.cardColor,
            border: Border.all(color: context.hairline),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const TypingDots(),
        ),
      );
}
