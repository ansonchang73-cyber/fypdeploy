// lib/core/providers/synchro_ai_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/synchro_ai_service.dart';
import '../../features/medication_management/providers/timeline_provider.dart'; // <--- Added import
import '../../features/medication_management/domain/entities/medication_task.dart'; // <--- Added import

final synchroAiServiceProvider = Provider<SynchroAiService>((ref) {
  return SynchroAiService(
    baseUrl: 'https://synchrom.vercel.app',
  );
});

// ... [Keep your SynchroAiState class exactly as it is] ...

class SynchroAiController extends Notifier<SynchroAiState> {
  @override
  SynchroAiState build() => const SynchroAiState();

  Future<void> send(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final service = ref.read(synchroAiServiceProvider);
    final List<SynchroChatTurn> historyForRequest = state.history;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearPendingAction: true,
      history: [...state.history, SynchroChatTurn('user', trimmed)],
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // 1. Read the REAL schedule data from your existing timelineProvider
      final scheduleAsync = ref.read(timelineProvider);
      
      // 2. Format the real data into a simple list the AI can read
      List<Map<String, String>> formattedSchedule = [];
      
      if (scheduleAsync.hasValue && scheduleAsync.value != null) {
        final List<MedicationTask> rawSchedule = List<MedicationTask>.from(scheduleAsync.value!);
        
        for (var task in rawSchedule) {
          formattedSchedule.add({
            'medication': task.name,
            'time': task.time,
            'frequency': task.frequency,
          });
        }
      }

      // 3. Package it into the payload
      final Map<String, dynamic> patientContext = {
        'userId': user?.uid ?? 'guest',
        'displayName': user?.displayName ?? 'Patient',
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