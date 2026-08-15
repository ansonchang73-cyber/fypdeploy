// lib/core/services/synchro_ai_service.dart
//
// Client for the /api/synchro-ai Vercel function that powers the top-bar
// "Synchro AI" assistant. Add the http package to pubspec.yaml first:
//   http: ^1.2.2

import 'dart:convert';
import 'package:http/http.dart' as http;

/// A structured reminder the backend wants the simulator to schedule.
class SynchroReminderAction {
  final String medicationName;
  final String dosage;
  final String triggerTime;

  const SynchroReminderAction({
    required this.medicationName,
    required this.dosage,
    required this.triggerTime,
  });

  factory SynchroReminderAction.fromJson(Map<String, dynamic> json) {
    return SynchroReminderAction(
      medicationName: json['medication_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      triggerTime: json['trigger_time'] as String? ?? '',
    );
  }
}

/// One turn of prior conversation, sent back so the assistant has context.
class SynchroChatTurn {
  final String role; // 'user' or 'assistant'
  final String content;
  const SynchroChatTurn(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Parsed reply for a single turn: what to show in the top bar, plus an
/// optional reminder action for the simulator to act on.
class SynchroAiResponse {
  final String reply;
  final SynchroReminderAction? action;

  const SynchroAiResponse({required this.reply, this.action});
}

class SynchroAiException implements Exception {
  final String message;
  SynchroAiException(this.message);
  @override
  String toString() => message;
}

class SynchroAiService {
  SynchroAiService({required this.baseUrl, this.sharedToken});

  /// Same origin as the deployed PWA — at runtime you can usually just
  /// pass Uri.base.origin instead of hardcoding it.
  final String baseUrl;

  /// Only needed if SYNCHRO_AI_SHARED_SECRET is set on the server.
  final String? sharedToken;

  Future<SynchroAiResponse> send(
    String message, {
    List<SynchroChatTurn> history = const [],
    Map<String, dynamic>? patientContext,
  }) async {
    final uri = Uri.parse('$baseUrl/api/synchro-ai');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (sharedToken != null) 'x-synchro-token': sharedToken!,
          },
          body: jsonEncode({
            'message': message,
            'history': history.map((t) => t.toJson()).toList(),
            if (patientContext != null) 'patientContext': patientContext,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw SynchroAiException(
        'Synchro AI is unavailable (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final actionJson = body['action'] as Map<String, dynamic>?;

    return SynchroAiResponse(
      reply: body['reply'] as String? ?? 'Got it.',
      action:
          actionJson != null ? SynchroReminderAction.fromJson(actionJson) : null,
    );
  }
}