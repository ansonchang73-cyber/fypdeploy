// lib/features/caregiver_dashboard/domain/usecases/compute_daily_adherence_percentage.dart
import '../entities/routine_dose.dart';

/// Simple completion percentage for the Home tab's pie chart — deliberately
/// much lighter than `adherence_analytics`'s `BuildAdherenceSummary`
/// (which also computes time-of-day breakdowns and a tier), since the
/// caregiver Home tab only ever needs the one number per patient. Pure
/// calculation, no Firestore.
class ComputeDailyAdherencePercentage {
  const ComputeDailyAdherencePercentage();

  double call(List<RoutineDose> doses) {
    if (doses.isEmpty) return 0.0;
    final completed = doses.where((d) => d.isCompleted).length;
    return (completed / doses.length) * 100;
  }
}
