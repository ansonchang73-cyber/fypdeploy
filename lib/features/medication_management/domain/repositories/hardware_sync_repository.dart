// lib/features/medication_management/domain/repositories/hardware_sync_repository.dart
import '../entities/upcoming_dose_candidate.dart';

abstract class HardwareSyncRepository {
  /// Starts listening for the physical dispenser's trigger flag on
  /// [userId]'s document and, when it fires, atomically marks the active
  /// task completed and writes a permanent log entry. Fire-and-forget,
  /// same as the original — this returns immediately, the listener keeps
  /// running independently.
  void listenAndProcessHardwareTriggers(String userId);

  /// True while a triggered completion is mid-transaction. Exposed so the
  /// sync controller can skip overlapping `checkAndSyncHardware` runs —
  /// this mirrors the original's single shared debounce flag exactly,
  /// just as instance state on the repository instead of a static
  /// class-level bool.
  bool get isProcessingTrigger;

  Future<List<UpcomingDoseCandidate>> fetchUpcomingDoses(String userId);

  /// Empty string clears the active task.
  Future<void> setActiveTaskId(String userId, String taskId);
}
