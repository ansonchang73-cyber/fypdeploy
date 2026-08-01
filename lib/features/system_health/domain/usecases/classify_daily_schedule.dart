// lib/features/system_health/domain/usecases/classify_daily_schedule.dart
import '../entities/daily_schedule_summary.dart';
import '../entities/scheduled_dose.dart';

/// Classifies today's doses into status tiers and produces both the
/// per-dose classification (for the schedule list) and the aggregate
/// counts (for the analytics card) from a single pass — no Flutter, no
/// Firestore, fully unit-testable with a plain list of [ScheduledDose].
///
/// This replaces TWO separate copies of "how late is this dose" that
/// used to live in `system_health_screen.dart`:
///  - `_buildNextMedicationCard`'s per-item logic, which correctly
///    handled AM/PM via a `parseToTodayDateTime` helper, and
///  - `_buildDetailedAnalyticsCard`'s missed/delayed counts, which used a
///    DIFFERENT, simpler parser that never checked AM/PM at all —
///    `"8:00 PM"` was parsed as hour 8, not 20.
///  Because the two used different parsers, the analytics card's
///  missed/delayed counts could silently disagree with the schedule list
///  directly below it for any PM-scheduled dose. Consolidating onto one
///  classification (using the correct AM/PM-aware parser everywhere)
///  fixes that mismatch as a side effect — it isn't a deliberate
///  behavior change, just no longer computing the same thing two
///  different, disagreeing ways.
class ClassifyDailySchedule {
  const ClassifyDailySchedule();

  DailyScheduleSummary call(List<ScheduledDose> doses, DateTime now) {
    final sorted = [...doses]
      ..sort(
        (a, b) => _parseToToday(a.time, now).compareTo(_parseToToday(b.time, now)),
      );

    final String? activeEligibleDoseId = _findActiveEligibleDoseId(sorted, now);

    final classified = sorted
        .map((dose) => _classify(dose, now, activeEligibleDoseId))
        .toList();

    final int completedCount =
        classified.where((c) => c.tier == DoseStatusTier.compliant).length;
    final int delayedCount =
        classified.where((c) => c.tier == DoseStatusTier.delayed).length;
    final int missedCount =
        classified.where((c) => c.tier == DoseStatusTier.missed).length;
    // Matches the original card's arithmetic exactly: "upcoming" here is
    // a remainder bucket covering ready-early/upcoming/ready-on-time
    // doses together, not a single tier.
    final int upcomingCount =
        doses.length - completedCount - delayedCount - missedCount;
    final double complianceRatio =
        doses.isNotEmpty ? completedCount / doses.length : 0.0;

    return DailyScheduleSummary(
      classifiedDoses: classified,
      completedCount: completedCount,
      delayedCount: delayedCount,
      missedCount: missedCount,
      upcomingCount: upcomingCount,
      complianceRatio: complianceRatio,
      activeEligibleDoseId: activeEligibleDoseId,
    );
  }

  String? _findActiveEligibleDoseId(List<ScheduledDose> sortedDoses, DateTime now) {
    for (final dose in sortedDoses) {
      if (dose.isCompleted) continue;
      final scheduled = _parseToToday(dose.time, now);
      final minutesEarly = -now.difference(scheduled).inMinutes;
      final isActionableNow = now.isAfter(scheduled) ||
          now.isAtSameMomentAs(scheduled) ||
          (scheduled.isAfter(now) && minutesEarly <= 15);
      if (isActionableNow) return dose.id;
    }
    return null;
  }

  ClassifiedDose _classify(
    ScheduledDose dose,
    DateTime now,
    String? activeEligibleDoseId,
  ) {
    final scheduled = _parseToToday(dose.time, now);
    final int minutesLate = now.difference(scheduled).inMinutes;
    final int minutesEarly = -minutesLate;

    DoseStatusTier tier;
    bool isActionable;

    if (dose.isCompleted) {
      tier = DoseStatusTier.compliant;
      isActionable = false;
    } else if (scheduled.isAfter(now)) {
      if (minutesEarly <= 15) {
        tier = DoseStatusTier.readyEarly;
        isActionable = true;
      } else {
        tier = DoseStatusTier.upcoming;
        isActionable = false;
      }
    } else {
      if (minutesLate >= 0 && minutesLate <= 15) {
        tier = DoseStatusTier.readyOnTime;
        isActionable = true;
      } else if (minutesLate > 15 && minutesLate <= 60) {
        tier = DoseStatusTier.delayed;
        isActionable = true;
      } else {
        tier = DoseStatusTier.missed;
        isActionable = false;
      }
    }

    // Matches the original's extra `task.status == TaskStatus.upcoming`
    // guard: a dose the user has already explicitly marked missed via
    // the dialog never re-qualifies for another prompt, even if it's
    // still sitting in the delayed time window.
    final bool requiresCaregiverPrompt = tier == DoseStatusTier.delayed &&
        dose.id == activeEligibleDoseId &&
        !dose.isMarkedMissed;

    return ClassifiedDose(
      dose: dose,
      tier: tier,
      minutesLate: minutesLate,
      isActionable: isActionable,
      requiresCaregiverPrompt: requiresCaregiverPrompt,
    );
  }

  /// AM/PM-aware parser — the one the original per-item list used.
  DateTime _parseToToday(String timeStr, DateTime now) {
    try {
      final cleanTime = timeStr.toUpperCase().trim();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');

      final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
      final parts = rawTimeStr.split(':');

      int hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return now;
    }
  }
}
