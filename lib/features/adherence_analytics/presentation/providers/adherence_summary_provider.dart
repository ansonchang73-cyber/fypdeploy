// lib/features/adherence_analytics/presentation/providers/adherence_summary_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication_management/domain/entities/medication_task.dart';
import '../../../medication_management/presentation/providers/medication_management_providers.dart';
import '../../../medication_management/presentation/providers/timeline_provider.dart';
import '../../domain/entities/adherence_summary.dart';
import '../../domain/usecases/build_adherence_summary.dart';

/// Derives today's [AdherenceSummary] from `medication_management`'s
/// `timelineProvider`. This is a legitimate cross-feature read (analytics
/// needs the day's schedule from somewhere) — what changed is that the
/// math itself no longer lives inline in the screen. `timelineProvider`
/// is left as-is here; `medication_management` still owns it and still
/// talks to Firestore directly today. That module's own decoupling is a
/// separate pass.
///
/// This is the signed-in user's own summary — `timelineProvider` is
/// always the current Firebase Auth user, and it also runs a
/// daily-adherence-reset side effect on first read each day. That's the
/// right behavior when you're looking at your own schedule, but not when
/// a caregiver is looking at someone else's — see
/// [adherenceSummaryForPatientProvider] below for that case.
final adherenceSummaryProvider = Provider<AsyncValue<AdherenceSummary>>((ref) {
  final scheduleAsync = ref.watch(timelineProvider);

  return scheduleAsync.whenData((schedule) {
    final doses = schedule
        .map(
          (task) => DoseRecord(
            time: task.time,
            isCompleted: task.status == TaskStatus.completed,
          ),
        )
        .toList();

    return const BuildAdherenceSummary().call(doses);
  });
});

/// Same math, but for an arbitrary [patientId] — used by the caregiver
/// dashboard's analytics tab. Reads directly from
/// `medicationScheduleRepositoryProvider.watchSchedule(patientId)`
/// instead of going through `timelineProvider`, deliberately: a
/// caregiver just opening this screen to look at a patient's data
/// shouldn't trigger that patient's daily-reset side effect the way
/// loading your own timeline does.
final adherenceSummaryForPatientProvider = Provider.family<
    AsyncValue<AdherenceSummary>, String>((ref, patientId) {
  final scheduleAsync = ref.watch(_patientScheduleProvider(patientId));

  return scheduleAsync.whenData((schedule) {
    final doses = schedule
        .map(
          (task) => DoseRecord(
            time: task.time,
            isCompleted: task.status == TaskStatus.completed,
          ),
        )
        .toList();

    return const BuildAdherenceSummary().call(doses);
  });
});

final _patientScheduleProvider = StreamProvider.family
    .autoDispose<List<MedicationTask>, String>((ref, patientId) {
      return ref
          .watch(medicationScheduleRepositoryProvider)
          .watchSchedule(patientId);
    });
