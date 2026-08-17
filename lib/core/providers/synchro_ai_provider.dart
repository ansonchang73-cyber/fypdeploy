// lib/core/providers/synchro_ai_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/synchro_ai_service.dart';

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
      
      // 2. Do the math in Flutter so the AI doesn't have to!
      List<Map<String, dynamic>> formattedSchedule = [];
      final now = DateTime.now();
      final currentMinutes = (now.hour * 60) + now.minute;
      
      if (scheduleAsync.hasValue && scheduleAsync.value != null) {
        final rawSchedule = List<dynamic>.from(scheduleAsync.value!);
        
        for (dynamic task in rawSchedule) {
          String timeString = task.time.toString();
          
          // Convert string to minutes since midnight for perfect sorting
          int taskMinutes = 9999;
          try {
            String t = timeString.toLowerCase();
            bool isPm = t.contains('pm');
            bool isAm = t.contains('am');
            t = t.replaceAll(RegExp(r'[^0-9:]'), '');
            List<String> parts = t.split(':');
            if (parts.isNotEmpty) {
              int h = int.parse(parts[0]);
              int m = parts.length > 1 ? int.parse(parts[1]) : 0;
              if (isPm && h < 12) h += 12;
              if (isAm && h == 12) h = 0;
              taskMinutes = (h * 60) + m;
            }
          } catch (_) {}

          formattedSchedule.add({
            'PILL_NAME': task.name.toString(),
            'SCHEDULED_TIME': timeString,
            'SORT_MINUTES': taskMinutes,
          });
        }
        
        // Sort the list chronologically
        formattedSchedule.sort((a, b) => (a['SORT_MINUTES'] as int).compareTo(b['SORT_MINUTES'] as int));
        
        // Tag the EXACT next medication so the AI can't possibly mess up
        bool foundNext = false;
        for (var item in formattedSchedule) {
          int tMin = item['SORT_MINUTES'] as int;
          item.remove('SORT_MINUTES'); // Hide the math from the AI
          
          if (tMin < currentMinutes) {
            item['STATUS'] = 'ALREADY PASSED';
          } else if (!foundNext && tMin != 9999) {
            item['STATUS'] = '*** NEXT UP ***'; // The secret cheat code
            foundNext = true;
          } else {
            item['STATUS'] = 'LATER TODAY';
          }
        }
      }

      final String time12 = '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

      // 3. Package it into the payload
      final Map<String, dynamic> patientContext = {
        'userId': user?.uid ?? 'guest',
        'CURRENT_TIME': time12,
        'todaySchedule': formattedSchedule.isNotEmpty ? formattedSchedule : 'No medications scheduled today.',
        'SYSTEM_RULE': 'Look at the todaySchedule array. Just read the medication with STATUS: "*** NEXT UP ***". DO NOT DO ANY MATH.'
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