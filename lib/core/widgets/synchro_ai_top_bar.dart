// lib/core/widgets/synchro_ai_top_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../providers/synchro_ai_provider.dart';
import 'glass_panel.dart';

/// The persistent "Synchro AI" bar. Pass it as a Scaffold's `appBar` and
/// it stays pinned across every tab of that Scaffold (e.g. all four tabs
/// in MainDashboardScreen, since they share one Scaffold via
/// IndexedStack). Tap it to open the chat sheet.
class SynchroAiTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const SynchroAiTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(synchroAiControllerProvider);

    // Show the reminder confirmation once, right when it arrives, then
    // clear it so it doesn't re-fire on the next rebuild.
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
      preferredSize: preferredSize,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: GestureDetector(
            onTap: () => _openChatSheet(context),
            child: SizedBox(
              height: 48,
              child: GlassPanel(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        aiState.isLoading ? 'Thinking…' : aiState.lastReply,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
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

class _SynchroAiChatSheet extends ConsumerStatefulWidget {
  const _SynchroAiChatSheet();

  @override
  ConsumerState<_SynchroAiChatSheet> createState() =>
      _SynchroAiChatSheetState();
}

class _SynchroAiChatSheetState extends ConsumerState<_SynchroAiChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(synchroAiControllerProvider.notifier).send(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            const SizedBox(height: 12),
            const Text(
              'Synchro AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: aiState.history.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          "Ask how SynchroM works, or say something like "
                          '"remind me to take Metformin at 8am".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: aiState.history.length,
                      itemBuilder: (context, index) {
                        final turn = aiState.history[index];
                        final isUser = turn.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppColors.primaryBlue
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              turn.content,
                              style: TextStyle(
                                color:
                                    isUser ? Colors.white : AppColors.textPrimary,
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
                  style: const TextStyle(
                    color: AppColors.criticalRed,
                    fontSize: 12,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask Synchro AI…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                          borderSide:
                              const BorderSide(color: AppColors.primaryBlue, width: 2),
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
                          onTap: _send,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.send,
                              size: 18,
                              color: Colors.white,
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