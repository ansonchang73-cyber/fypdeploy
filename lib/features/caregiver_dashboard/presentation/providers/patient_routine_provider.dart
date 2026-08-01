// lib/features/caregiver_dashboard/presentation/providers/patient_routine_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication_management/domain/entities/medication_task.dart';
import '../../../medication_management/presentation/providers/medication_management_providers.dart';
import '../../domain/entities/routine_dose.dart';

/// A given patient's full day of doses, read-only. Deliberately reads
/// straight from `medicationScheduleRepositoryProvider.watchSchedule`
/// (already parameterized by user ID) rather than `timelineProvider` —
/// the latter is locked to the signed-in user and also runs a
/// daily-adherence-reset side effect on first read, which shouldn't fire
/// just because a caregiver opened this screen.
final patientRoutineProvider = StreamProvider.family
    .autoDispose<List<RoutineDose>, String>((ref, patientId) {
      return ref
          .watch(medicationScheduleRepositoryProvider)
          .watchSchedule(patientId)
          .map(
            (tasks) => tasks
                .map(
                  (task) => RoutineDose(
                    name: task.name,
                    dosage: task.dosage,
                    time: task.time,
                    isCompleted: task.status == TaskStatus.completed,
                  ),
                )
                .toList(),
          );
    });
