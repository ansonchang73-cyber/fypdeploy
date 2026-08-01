// lib/features/medication_management/domain/repositories/medication_schedule_repository.dart
import '../entities/medication_schedule_plan.dart';
import '../entities/medication_task.dart';

abstract class MedicationScheduleRepository {
  /// Today's schedule for [userId], live-updating.
  Stream<List<MedicationTask>> watchSchedule(String userId);

  /// If this is the first read today, rolls yesterday's completed/missed
  /// doses back to 'upcoming' for the new day.
  Future<void> resetDailyAdherenceIfNeeded(String userId);

  /// Marks a dose completed and writes a permanent entry to the
  /// `medication_logs` history collection.
  Future<void> markAsTaken(String taskId, String userId);

  /// Writes one Firestore document per slot in [plan] under [userId].
  /// Returns how many documents were actually written (mirrors the
  /// original screen's "N future active slots created" messaging).
  Future<int> createScheduleSlots({
    required String userId,
    required String medicationName,
    required MedicationSchedulePlan plan,
    required String instructions,
  });
}
