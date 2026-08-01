// lib/features/medication_management/domain/entities/upcoming_dose_candidate.dart

/// A still-upcoming dose, as far as the hardware sync is concerned — just
/// enough to decide which one the physical dispenser should treat as
/// "active" right now.
class UpcomingDoseCandidate {
  final String id;
  final String reminderTime;

  const UpcomingDoseCandidate({required this.id, required this.reminderTime});
}
