// lib/features/medication_management/domain/usecases/schedule_usecases.dart
import '../entities/medication_task.dart';
import '../repositories/medication_schedule_repository.dart';

class WatchTodaySchedule {
  const WatchTodaySchedule(this._repository);
  final MedicationScheduleRepository _repository;

  Stream<List<MedicationTask>> call(String userId) =>
      _repository.watchSchedule(userId);
}

class MarkDoseTaken {
  const MarkDoseTaken(this._repository);
  final MedicationScheduleRepository _repository;

  Future<void> call(String taskId, String userId) =>
      _repository.markAsTaken(taskId, userId);
}

class ResetDailyAdherenceIfNeeded {
  const ResetDailyAdherenceIfNeeded(this._repository);
  final MedicationScheduleRepository _repository;

  Future<void> call(String userId) =>
      _repository.resetDailyAdherenceIfNeeded(userId);
}
