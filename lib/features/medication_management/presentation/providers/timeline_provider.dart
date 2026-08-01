// lib/features/medication_management/presentation/providers/timeline_provider.dart
//
// Public API unchanged from the old `providers/timeline_provider.dart`:
// `timelineProvider` and `providerForAuthUserChanges` are consumed
// directly by `adherence_analytics` and `system_health`, and indirectly
// by `core/providers/hardware_listener_provider.dart` — all of those
// import paths needed updating as part of this delivery (see the module
// summary), but the provider names and behavior here did not change.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medication_task.dart';
import 'medication_management_providers.dart';

class TimelineNotifier extends StateNotifier<AsyncValue<List<MedicationTask>>> {
  TimelineNotifier(this._ref) : super(const AsyncValue.loading()) {
    _initTimeline();
  }

  final Ref _ref;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  StreamSubscription<List<MedicationTask>>? _subscription;

  Future<void> _initTimeline() async {
    if (_userId == null) {
      state = AsyncValue.error(
        Exception("No active user authorization link found."),
        StackTrace.current,
      );
      return;
    }

    try {
      await _ref.read(resetDailyAdherenceIfNeededProvider).call(_userId);
      _subscription = _ref
          .read(watchTodayScheduleProvider)
          .call(_userId)
          .listen(
            (tasks) => state = AsyncValue.data(tasks),
            onError: (Object err, StackTrace stack) =>
                state = AsyncValue.error(err, stack),
          );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> markAsTaken(String taskId) async {
    if (_userId == null) return;
    try {
      await _ref.read(markDoseTakenProvider).call(taskId, _userId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final timelineProvider =
    StateNotifierProvider<TimelineNotifier, AsyncValue<List<MedicationTask>>>((
      ref,
    ) {
      // Forces Riverpod to fully destroy and reconstruct this notifier
      // whenever the signed-in user changes — unchanged from the original.
      ref.watch(providerForAuthUserChanges);
      return TimelineNotifier(ref);
    });

final providerForAuthUserChanges = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
