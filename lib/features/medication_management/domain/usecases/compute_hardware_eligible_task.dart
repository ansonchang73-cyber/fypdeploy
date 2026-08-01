// lib/features/medication_management/domain/usecases/compute_hardware_eligible_task.dart
import '../entities/upcoming_dose_candidate.dart';

/// Picks which upcoming dose the physical dispenser hardware should treat
/// as "active" right now: eligible if it's due within the next 15
/// minutes, or overdue by no more than 60 minutes; among eligible doses,
/// the one closest to now wins. Returns null if nothing qualifies.
///
/// Extracted from `MedicationSyncService.checkAndSyncHardware` — pure
/// calculation now, no Firestore query or write mixed in.
class ComputeHardwareEligibleTask {
  const ComputeHardwareEligibleTask();

  String? call(List<UpcomingDoseCandidate> candidates, DateTime now) {
    final int nowMinutes = now.hour * 60 + now.minute;
    final List<UpcomingDoseCandidate> eligible = [];

    for (final candidate in candidates) {
      try {
        final parts = candidate.reminderTime.split(':');
        final int taskHour = int.parse(parts[0].trim());
        final int taskMinute = int.parse(parts[1].trim());
        final int taskMinutes = taskHour * 60 + taskMinute;
        final int windowDifference = taskMinutes - nowMinutes;

        if (windowDifference >= 0) {
          if (windowDifference <= 15) eligible.add(candidate);
        } else {
          if (windowDifference.abs() <= 60) eligible.add(candidate);
        }
      } catch (_) {
        // Same as the original: a candidate with an unparsable
        // reminderTime is silently skipped, not treated as eligible.
      }
    }

    if (eligible.isEmpty) return null;

    int minutesFromNow(UpcomingDoseCandidate c) {
      final parts = c.reminderTime.split(':');
      final int tMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      return (tMinutes - nowMinutes).abs();
    }

    eligible.sort((a, b) => minutesFromNow(a).compareTo(minutesFromNow(b)));
    return eligible.first.id;
  }
}
