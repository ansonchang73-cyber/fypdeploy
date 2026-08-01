// lib/features/system_health/domain/repositories/medication_status_repository.dart
//
// Narrow, single-purpose interface for the one write this feature makes
// to the medication schedule: marking a dose as missed from the
// caregiver-prompt dialog. `medication_management` (untouched in this
// pass) owns the rest of that collection's writes via `TimelineNotifier`.
abstract class MedicationStatusRepository {
  Future<void> markAsMissed(String taskId);
}
