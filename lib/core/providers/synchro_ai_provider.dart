// lib/core/providers/synchro_ai_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/synchro_ai_service.dart';

/// Points at the deployed API. `Uri.base.origin` resolves to whatever
/// domain the Flutter web app is actually running on, so this works
/// unchanged on your Vercel preview and production URLs.
final synchroAiServiceProvider = Provider<SynchroAiService>((ref) {
  return SynchroAiService(
    baseUrl: 'https://synchrom.vercel.app',
    // sharedToken: 'put-the-same-value-as-SYNCHRO_AI_SHARED_SECRET-here',
  );
});

class SynchroAiState {
  final List<SynchroChatTurn> history;
  final String lastReply;
  final bool isLoading;
  final SynchroReminderAction? pendingAction;
  final String? error;

  const SynchroAiState({
    this.history = const [],
    this.lastReply = "Hi, I'm Synchro AI. Ask me anything or set a reminder.",
    this.isLoading = false,
    this.pendingAction,
    this.error,
  });

  SynchroAiState copyWith({
    List<SynchroChatTurn>? history,
    String? lastReply,
    bool? isLoading,
    SynchroReminderAction? pendingAction,
    bool clearPendingAction = false,
    String? error,
    bool clearError = false,
  }) {
    return SynchroAiState(
      history: history ?? this.history,
      lastReply: lastReply ?? this.lastReply,
      isLoading: isLoading ?? this.isLoading,
      pendingAction:
          clearPendingAction ? null : (pendingAction ?? this.pendingAction),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SynchroAiController extends Notifier<SynchroAiState> {
  @override
  SynchroAiState build() => const SynchroAiState();

  Future<void> send(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final service = ref.read(synchroAiServiceProvider);

    // Captured *before* the optimistic update just below — the request
    // should still only carry the turns that came before this message,
    // since `service.send` appends `trimmed` itself. Reading
    // `state.history` after the update would double it up in the prompt
    // sent to the model.
    final List<SynchroChatTurn> historyForRequest = state.history;

    // Show the user's own message immediately instead of waiting for the
    // round trip to finish — this is what lets the chat sheet's bubble
    // animation and the top bar's "Thinking" indicator actually feel
    // responsive rather than everything popping in at once at the end.
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearPendingAction: true,
      history: [...state.history, SynchroChatTurn('user', trimmed)],
    );

    try {
      final response = await service.send(trimmed, history: historyForRequest);

      state = state.copyWith(
        history: [...state.history, SynchroChatTurn('assistant', response.reply)],
        lastReply: response.reply,
        isLoading: false,
        pendingAction: response.action,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Synchro AI is unavailable right now.',
      );
      if (kDebugMode) debugPrint('SynchroAi error: $e');
    }
  }

  /// Call after you've acted on state.pendingAction (e.g. shown the
  /// confirmation) so it doesn't fire again on the next rebuild.
  void clearPendingAction() {
    state = state.copyWith(clearPendingAction: true);
  }
  /// Wipes the chat history and resets the top bar greeting
  void clearHistory() {
    state = state.copyWith(
      history: const [],
      lastReply: "Hi, I'm Synchro AI. Ask me anything or set a reminder.",
      clearError: true,
      clearPendingAction: true,
    );
  }
}

final synchroAiControllerProvider =
    NotifierProvider<SynchroAiController, SynchroAiState>(
  SynchroAiController.new,
);
