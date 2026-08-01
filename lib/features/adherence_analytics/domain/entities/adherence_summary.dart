// lib/features/adherence_analytics/domain/entities/adherence_summary.dart

/// Minimal input the analytics math needs: just a reminder time and
/// whether it was completed. Deliberately NOT the medication_management
/// feature's `MedicationTask` — that would make this feature's domain
/// layer depend on another feature's (still-Firestore-coupled) provider
/// file. The presentation layer adapts `MedicationTask` down to this
/// shape; the domain layer never needs to know `MedicationTask` exists.
class DoseRecord {
  final String time;
  final bool isCompleted;

  const DoseRecord({required this.time, required this.isCompleted});
}

/// Business-rule tiers for overall adherence. The threshold values
/// (80% / 50%) live in the use case that produces this, not in a widget.
enum AdherenceTier { excellent, good, needsAttention }

/// Fully computed analytics summary, ready for a screen to render as-is.
class AdherenceSummary {
  final int totalDoses;
  final int completedDoses;
  final int overallAdherencePercent;
  final AdherenceTier tier;

  /// 0.0 - 1.0 fraction of doses taken in each window
  final double morningAdherence;
  final double afternoonAdherence;
  final double eveningAdherence;

  const AdherenceSummary({
    required this.totalDoses,
    required this.completedDoses,
    required this.overallAdherencePercent,
    required this.tier,
    required this.morningAdherence,
    required this.afternoonAdherence,
    required this.eveningAdherence,
  });
}
