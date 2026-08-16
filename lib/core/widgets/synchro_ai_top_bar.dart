// lib/core/widgets/synchro_ai_top_bar.dart
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _smoothPulse; // Added for smoother easing

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Applies an ease-in-out curve so the animation doesn't sharply reverse direction
    _smoothPulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
              animation: _smoothPulse, // Using the smoothed curve
              builder: (context, child) {
                final glow = 0.30 + (_smoothPulse.value * 0.20);
                final scale = 1.0 + (_smoothPulse.value * 0.015); // Subtle 1.5% breathing scale
                
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryBlue, Color(0xFF123E91)],
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
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
                        Text(
                          aiState.isLoading ? 'Thinking…' : aiState.lastReply,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
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

class _SynchroAiChatSheetState extends ConsumerState<_SynchroAiChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    ref.read(synchroAiControllerProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), // Smoothed out scroll animation
          curve: Curves.easeOutQuart, // Nicer easing curve for the scroll
        );
      }
    });
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
            children: _kQuickSuggestions.map((s) {
              return GestureDetector(
                onTap: () => _sendText(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(synchroAiControllerProvider);

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
            
            // --- NEW: Header with centered text and the trash icon ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer to perfectly center the title
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
            // ---------------------------------------------------------
            
            Expanded(
              child: aiState.history.isEmpty
                  ? Center(child: SingleChildScrollView(child: _buildSuggestions()))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: aiState.history.length,
                      itemBuilder: (context, index) {
                        final turn = aiState.history[index];
                        final isUser = turn.role == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isUser ? AppColors.primaryBlue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              turn.content,
                              style: TextStyle(
                                color: isUser ? Colors.white : AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
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
                  aiState.isLoading
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : GestureDetector(
                          onTap: _sendFromField,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}