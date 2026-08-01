// lib/features/system_health/domain/entities/daily_schedule_summary.dart
import 'scheduled_dose.dart';

/// Full result of classifying today's schedule: every dose with its
/// status, plus the aggregate counts the analytics card shows.
class DailyScheduleSummary {
  final List<ClassifiedDose> classifiedDoses;
  final int completedCount;
  final int delayedCount;
  final int missedCount;
  final int upcomingCount;

  /// 0.0 - 1.0
  final double complianceRatio;

  /// The single dose that's currently due (or just became due) and should
  /// prompt the caregiver dialog if it slips into the delayed window —
  /// null if nothing is due right now. Only ever one at a time: the
  /// first not-yet-completed dose in time order that's actionable now.
  final String? activeEligibleDoseId;

  const DailyScheduleSummary({
    required this.classifiedDoses,
    required this.completedCount,
    required this.delayedCount,
    required this.missedCount,
    required this.upcomingCount,
    required this.complianceRatio,
    required this.activeEligibleDoseId,
  });
}
