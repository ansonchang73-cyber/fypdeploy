// lib/core/providers/synchro_ai_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/synchro_ai_service.dart';

// FIX: Corrected path to include the presentation folder!
import '../../features/medication_management/presentation/providers/timeline_provider.dart';

final synchroAiServiceProvider = Provider<SynchroAiService>((ref) {
  return SynchroAiService(
    baseUrl: 'https://synchrom.vercel.app',
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
    final List<SynchroChatTurn> historyForRequest = state.history.toList();

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearPendingAction: true,
      history: [...state.history, SynchroChatTurn('user', trimmed)],
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // 1. Read the REAL schedule data
      final scheduleAsync = ref.read(timelineProvider);
      
      // 2. Format the real data into a simple list the AI can read
      List<Map<String, String>> formattedSchedule = [];
      
      if (scheduleAsync.hasValue && scheduleAsync.value != null) {
        // Using dynamic to avoid path errors with MedicationTask
        final rawSchedule = List<dynamic>.from(scheduleAsync.value!);
        
        for (dynamic task in rawSchedule) {
          formattedSchedule.add({
            'medication': task.name.toString(),
            'time': task.time.toString(),
            'frequency': task.frequency.toString(),
          });
        }
      }
      
      // --- ADD THIS TO GET THE LOCAL TIME ---
      final now = DateTime.now();
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final hour12 = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final String localTime = '$hour12:${now.minute.toString().padLeft(2, '0')} $amPm';
      // --------------------------------------
      // 3. Package it into the payload
      final Map<String, dynamic> patientContext = {
        'userId': user?.uid ?? 'guest',
        'displayName': user?.displayName ?? 'Patient',
        'currentTime': localTime, // <--- ADD THIS LINE
        'todaySchedule': formattedSchedule.isNotEmpty ? formattedSchedule : 'No medications scheduled today.',
      };

      final response = await service.send(
        trimmed,
        history: historyForRequest,
        patientContext: patientContext,
      );

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

  void clearPendingAction() {
    state = state.copyWith(clearPendingAction: true);
  }

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