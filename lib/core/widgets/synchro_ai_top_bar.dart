// lib/core/widgets/synchro_ai_top_bar.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../providers/synchro_ai_provider.dart';

class SynchroAiTopBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const SynchroAiTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  ConsumerState<SynchroAiTopBar> createState() => _SynchroAiTopBarState();
}

class _SynchroAiTopBarState extends ConsumerState<SynchroAiTopBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _smoothPulse;

  // Separate, longer-period controller for the sparkles icon's idle
  // wobble/bob — deliberately not locked to the same cycle as the glow
  // pulse, so the bar doesn't feel like it's animating on a single
  // metronome.
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _smoothPulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(synchroAiControllerProvider);

    ref.listen(synchroAiControllerProvider, (previous, next) {
      final action = next.pendingAction;
      if (action != null && previous?.pendingAction != action) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder set: ${action.medicationName}'
              '${action.dosage.isNotEmpty ? ' (${action.dosage})' : ''} '
              'at ${action.triggerTime}',
            ),
            backgroundColor: AppColors.primaryBlue,
          ),
        );
        ref.read(synchroAiControllerProvider.notifier).clearPendingAction();
      }
    });

    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: GestureDetector(
            onTap: () => _openChatSheet(context),
            child: AnimatedBuilder(
              animation: _smoothPulse,
              builder: (context, child) {
                final glow = 0.30 + (_smoothPulse.value * 0.22);
                final scale = 1.0 + (_smoothPulse.value * 0.018);
                // A faint color breathe on top of the glow/scale, so the
                // pulse reads as one cohesive "alive" effect rather than
                // just a shadow getting bigger.
                final Color topColor = Color.lerp(
                  AppColors.primaryBlue,
                  const Color(0xFF1B63D9),
                  _smoothPulse.value,
                )!;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [topColor, const Color(0xFF123E91)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: glow),
                          blurRadius: 22,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      final double wobble =
                          math.sin(_iconController.value * 2 * math.pi) * 0.16;
                      final double bob =
                          math.sin(_iconController.value * 2 * math.pi) * 1.4;
                      return Transform.translate(
                        offset: Offset(0, bob),
                        child: Transform.rotate(angle: wobble, child: child),
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Synchro AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Cross-fades + slides between "Thinking" (with
                        // live dots) and the latest reply, instead of the
                        // text just snapping to new content mid-pulse.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.18),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: aiState.isLoading
                              ? const Row(
                                  key: ValueKey('thinking'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Thinking',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    SizedBox(width: 5),
                                    _TypingDots(color: Colors.white70, dotSize: 4),
                                  ],
                                )
                              : Text(
                                  aiState.lastReply,
                                  key: ValueKey(aiState.lastReply),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 18, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SynchroAiChatSheet(),
    );
  }
}

const _kQuickSuggestions = [
  "What's on my schedule today?",
  'Remind me to take my medication',
  "How's my adherence this week?",
  'How do I add a new medication?',
];

class _SynchroAiChatSheet extends ConsumerStatefulWidget {
  const _SynchroAiChatSheet();

  @override
  ConsumerState<_SynchroAiChatSheet> createState() => _SynchroAiChatSheetState();
}

class _SynchroAiChatSheetState extends ConsumerState<_SynchroAiChatSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Drives the staggered fade/slide-in of the quick-suggestion chips the
  // first time they appear.
  late final AnimationController _suggestionsController;

  bool _sendPressed = false;

  @override
  void initState() {
    super.initState();
    _suggestionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    ref.read(synchroAiControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _sendFromField() {
    final text = _controller.text;
    _sendText(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Ask how SynchroM works, or try one of these:',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(_kQuickSuggestions.length, (i) {
              final double start = (i * 0.12).clamp(0.0, 1.0);
              final double end = (start + 0.55).clamp(0.0, 1.0);
              final animation = CurvedAnimation(
                parent: _suggestionsController,
                curve: Interval(start, end, curve: Curves.easeOutCubic),
              );
              final suggestion = _kQuickSuggestions[i];

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: animation.value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - animation.value)),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () => _sendText(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(synchroAiControllerProvider);

    // Auto-scroll whenever a new bubble lands — either the user's own
    // message (added the moment `send()` fires) or the assistant's reply
    // arriving once loading finishes.
    ref.listen(synchroAiControllerProvider, (previous, next) {
      final bool historyGrew =
          previous != null && next.history.length > previous.history.length;
      final bool justFinishedLoading = previous?.isLoading == true && !next.isLoading;
      if (historyGrew || justFinishedLoading) {
        _scrollToBottom();
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    'Synchro AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.trash, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      ref.read(synchroAiControllerProvider.notifier).clearHistory();
                    },
                    tooltip: 'Clear Chat',
                  ),
                ],
              ),
            ),

            Expanded(
              child: aiState.history.isEmpty
                  ? Center(child: SingleChildScrollView(child: _buildSuggestions()))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: aiState.history.length + (aiState.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        // The typing indicator always sits one slot past
                        // the last real message — it's only ever a "new"
                        // item (never re-keyed against an existing
                        // bubble), so it gets its own fresh entrance too.
                        if (aiState.isLoading && index == aiState.history.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: _TypingBubble(),
                          );
                        }

                        final turn = aiState.history[index];
                        final isUser = turn.role == 'user';
                        return _AnimatedChatBubble(isUser: isUser, content: turn.content);
                      },
                    ),
            ),
            if (aiState.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  aiState.error!,
                  style: const TextStyle(color: AppColors.criticalRed, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendFromField(),
                      decoration: InputDecoration(
                        hintText: 'Ask Synchro AI…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: aiState.isLoading
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : GestureDetector(
                            key: const ValueKey('send'),
                            onTapDown: (_) => setState(() => _sendPressed = true),
                            onTapUp: (_) => setState(() => _sendPressed = false),
                            onTapCancel: () => setState(() => _sendPressed = false),
                            onTap: _sendFromField,
                            child: AnimatedScale(
                              scale: _sendPressed ? 0.86 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.send, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chat bubble that fades and slides up the first time it's built —
/// which, thanks to `ListView.builder` reusing existing indices' State,
/// is exactly when it's newly appended to the list. Older bubbles at
/// earlier indices keep their already-finished (opacity 1, offset 0)
/// animation state and don't replay it.
class _AnimatedChatBubble extends StatefulWidget {
  const _AnimatedChatBubble({required this.isUser, required this.content});

  final bool isUser;
  final String content;

  @override
  State<_AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<_AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.06 : -0.06, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: widget.isUser ? AppColors.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.content,
              style: TextStyle(
                color: widget.isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "assistant is typing" bubble shown at the end of the list while a
/// reply is in flight.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const _TypingDots(color: AppColors.primaryBlue, dotSize: 6),
    );
  }
}

/// Three dots that bounce in a staggered wave — used both for the top
/// bar's "Thinking" state and the chat sheet's typing-indicator bubble,
/// so the two read as the same visual language.
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color, this.dotSize = 5});

  final Color color;
  final double dotSize;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final double t = (_controller.value + (i * 0.22)) % 1.0;
            final double bounce = (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
            final double scale = 0.55 + bounce * 0.65;
            final double opacity = 0.35 + bounce * 0.65;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
