// lib/features/medication_management/domain/usecases/should_show_task_at_hour.dart
import '../entities/medication_task.dart';

/// Decides whether [task] should render in the timeline's hour-row for
/// [currentHour] on [targetedDay]. Extracted verbatim from
/// `_shouldShowTaskAtHour` in the old `timeline_screen.dart`.
///
/// Note on the first branch below: it only matches frequency strings
/// shaped like "3 Times a day (Every 8 hours)". But
/// `BuildMedicationSchedulePlan` (this feature's own scheduling use case)
/// writes "Time(s) a day" frequencies as separate pre-expanded documents,
/// each labeled just "3 Times a day" with no "(Every N hours)" suffix —
/// so that regex never actually matches anything this app creates today,
/// and the fallback `baseHour == currentHour` check at the bottom handles
/// those documents correctly anyway (each one already has its own
/// specific `reminderTime`). This branch is dead code with the current
/// writer, kept as-is since removing it wasn't asked for and it's
/// harmless — but worth knowing about if you're trying to figure out why
/// it never seems to trigger.
class ShouldShowTaskAtHour {
  const ShouldShowTaskAtHour();

  bool call(MedicationTask task, int currentHour, int targetedDay) {
    try {
      final int baseHour = int.parse(task.time.split(':')[0]);
      final String frequencyText = task.frequency;

      if (frequencyText.contains('Times a day (Every')) {
        final RegExp regExp = RegExp(
          r'(\d+)\s+Times a day \(Every\s+(\d+)\s+hours\)',
        );
        final match = regExp.firstMatch(frequencyText);

        if (match != null) {
          final int totalTimes = int.parse(match.group(1)!);
          final int hourInterval = int.parse(match.group(2)!);

          for (int i = 0; i < totalTimes; i++) {
            int calculatedHour = (baseHour + (i * hourInterval)) % 24;
            if (calculatedHour == currentHour) {
              return true;
            }
          }
          return false;
        }
      }

      if (frequencyText.toLowerCase().contains('every') &&
          frequencyText.toLowerCase().contains('day')) {
        final RegExp dayRegExp = RegExp(r'Every\s+(\d+)');
        final match = dayRegExp.firstMatch(frequencyText);

        if (match != null) {
          final int dayInterval = int.parse(match.group(1)!);

          if (dayInterval > 0) {
            final bool dayMatchesPattern = (targetedDay % dayInterval) == 1;
            return dayMatchesPattern && (baseHour == currentHour);
          }
        }
      }

      return baseHour == currentHour;
    } catch (_) {
      return false;
    }
  }
}
