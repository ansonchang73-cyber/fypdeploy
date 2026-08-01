// lib/features/medication_management/domain/entities/medication_schedule_plan.dart

/// A single hour:minute pairing, kept as its own tiny type instead of a
/// raw `TimeOfDay` (a Flutter type) so the domain layer stays Flutter-free.
class ScheduleTime {
  final int hour;
  final int minute;

  const ScheduleTime({required this.hour, required this.minute});

  /// "HH:MM", zero-padded — the exact format written to Firestore's
  /// `reminderTime` field and read back everywhere else in the app.
  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Everything the medication form collects before it's turned into
/// Firestore documents.
class MedicationScheduleRequest {
  final String name;
  final String dosageValue;
  final String dosageUnit;
  final String frequencyType;
  final int frequencyNumber;
  final int? intervalHours;
  final ScheduleTime initialTime;
  final String instructions;

  const MedicationScheduleRequest({
    required this.name,
    required this.dosageValue,
    required this.dosageUnit,
    required this.frequencyType,
    required this.frequencyNumber,
    required this.intervalHours,
    required this.initialTime,
    required this.instructions,
  });
}

/// Result of turning a [MedicationScheduleRequest] into concrete dose
/// slots — one Firestore document gets created per entry in [slotTimes].
class MedicationSchedulePlan {
  final String dosage;
  final String frequencyLabel;
  final List<ScheduleTime> slotTimes;
  final int skippedPastSlotCount;

  const MedicationSchedulePlan({
    required this.dosage,
    required this.frequencyLabel,
    required this.slotTimes,
    required this.skippedPastSlotCount,
  });
}
