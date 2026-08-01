// lib/features/profile/domain/entities/adherence_report.dart

/// One row of medication-taking history, already translated out of
/// Firestore's document shape by the data layer.
class DoseLogEntry {
  final DateTime timestamp;

  /// Raw reminder time string as stored (e.g. "08:00" or "8:00 AM"),
  /// used for the morning/afternoon/evening bucketing.
  final String reminderTime;
  final String medicationName;
  final bool isCompleted;

  const DoseLogEntry({
    required this.timestamp,
    required this.reminderTime,
    required this.medicationName,
    required this.isCompleted,
  });
}

/// One row of a patient's *current* daily medication schedule — distinct
/// from [DoseLogEntry], which is a specific historical dose event. This
/// is "what medications, at what times", not "what happened on what day".
class MedicationScheduleEntry {
  final String medicationName;
  final String reminderTime;

  const MedicationScheduleEntry({
    required this.medicationName,
    required this.reminderTime,
  });
}

/// Fully computed adherence report, ready to be handed to a renderer
/// (PDF, screen, whatever). All the math that produces this is in
/// `domain/usecases/build_adherence_report.dart` — nothing in this file
/// does any calculation.
class AdherenceReportData {
  final String reportLabel;
  final String patientName;
  final DateTime generatedAt;
  final int totalDoses;
  final int completedDoses;
  final int missedDoses;
  final int overallAdherencePercent;

  /// How many daily dose slots the patient currently has active — the
  /// per-day multiplier behind [totalDoses]'s "days in period x doses
  /// per day" denominator.
  final int dosesPerDay;

  /// First day of the report period (always the 1st of the target
  /// month) and how many days it spans — together, these let a renderer
  /// walk every calendar day in the period (e.g. for a per-day adherence
  /// table), not just the days that happen to have a log entry.
  final DateTime periodStart;
  final int daysInPeriod;

  /// The patient's current medications and their scheduled times, latest
  /// time of day first — shown above the detailed dose log in a report so
  /// it's clear what the log's entries are actually measuring against.
  final List<MedicationScheduleEntry> medicationSchedule;

  /// 0.0 - 1.0 fraction of doses taken in each window
  final double morningAdherence;
  final double afternoonAdherence;
  final double eveningAdherence;

  final List<DoseLogEntry> logs;

  const AdherenceReportData({
    required this.reportLabel,
    required this.patientName,
    required this.generatedAt,
    required this.totalDoses,
    required this.completedDoses,
    required this.missedDoses,
    required this.overallAdherencePercent,
    required this.dosesPerDay,
    required this.periodStart,
    required this.daysInPeriod,
    required this.medicationSchedule,
    required this.morningAdherence,
    required this.afternoonAdherence,
    required this.eveningAdherence,
    required this.logs,
  });
}