// lib/features/system_health/domain/entities/scheduled_dose.dart
//
// Minimal shape the classification logic needs. Deliberately NOT
// medication_management's `MedicationTask` — same reasoning as
// `adherence_analytics`'s `DoseRecord`: this feature's domain layer
// shouldn't depend on another feature's still-Firestore-coupled provider
// file. The presentation layer adapts `MedicationTask` down to this.
class ScheduledDose {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool isCompleted;

  /// True if this dose's raw Firestore status is explicitly 'missed'
  /// (set by the caregiver-prompt dialog's "Missed Entirely" button) —
  /// distinct from a dose that just *computes* as missed by elapsed
  /// time. Needed so the caregiver prompt doesn't fire again for a dose
  /// the user already resolved; see `ClassifyDailySchedule`.
  final bool isMarkedMissed;

  const ScheduledDose({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isCompleted,
    required this.isMarkedMissed,
  });
}

/// Status tiers for a single dose, replacing the ad-hoc
/// color/icon/label-string combinations that used to be computed inline
/// in the screen for every list item.
enum DoseStatusTier {
  /// Already taken.
  compliant,

  /// Not yet due, but within the 15-minute early window.
  readyEarly,

  /// Not yet due, and more than 15 minutes away.
  upcoming,

  /// Due, within 15 minutes of the scheduled time.
  readyOnTime,

  /// 15-60 minutes past the scheduled time.
  delayed,

  /// More than 60 minutes past the scheduled time — locked out.
  missed,
}

class ClassifiedDose {
  final ScheduledDose dose;
  final DoseStatusTier tier;

  /// Minutes past the scheduled time; negative means still early.
  final int minutesLate;
  final bool isActionable;

  /// True exactly once per dose lifecycle: when it's the single
  /// currently-due dose AND has just slipped into the delayed window AND
  /// hasn't already been manually resolved. The screen still applies its
  /// own "have I already shown this dialog this session" check before
  /// acting on this — see `activePromptTaskIdProvider` in the presentation
  /// layer — but the underlying business rule of *which* dose qualifies
  /// lives here now instead of inline in the widget tree.
  final bool requiresCaregiverPrompt;

  const ClassifiedDose({
    required this.dose,
    required this.tier,
    required this.minutesLate,
    required this.isActionable,
    required this.requiresCaregiverPrompt,
  });

  bool get isMissed => tier == DoseStatusTier.missed;
}
