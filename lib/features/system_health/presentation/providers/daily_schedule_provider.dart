// lib/features/system_health/presentation/providers/daily_schedule_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication_management/domain/entities/medication_task.dart';
import '../../../medication_management/presentation/providers/timeline_provider.dart';
import '../../domain/entities/daily_schedule_summary.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../domain/usecases/classify_daily_schedule.dart';

/// Derives today's [DailyScheduleSummary] from `medication_management`'s
/// `timelineProvider` — the same cross-feature read the original screen
/// made, just no longer doing the classification math inline. As with
/// `adherence_analytics`, `medication_management` itself is untouched
/// here; this only adapts its output.
///
/// Recomputes whenever `timelineProvider` emits a new list (i.e. on every
/// Firestore snapshot update) — same as the original, which recalculated
/// `DateTime.now()` on every widget rebuild rather than on a ticking
/// timer. No periodic timer is introduced here either.
final dailyScheduleProvider = Provider<AsyncValue<DailyScheduleSummary>>((ref) {
  final scheduleAsync = ref.watch(timelineProvider);

  return scheduleAsync.whenData((tasks) {
    final doses = tasks
        .map(
          (task) => ScheduledDose(
            id: task.id,
            name: task.name,
            dosage: task.dosage,
            time: task.time,
            isCompleted: task.status == TaskStatus.completed,
            isMarkedMissed: task.status == TaskStatus.missed,
          ),
        )
        .toList();

    return const ClassifyDailySchedule().call(doses, DateTime.now());
  });
});
