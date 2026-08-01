// lib/features/profile/domain/usecases/build_adherence_report.dart
import '../entities/adherence_report.dart';

/// Turns raw dose history into an [AdherenceReportData] summary:
/// completion counts, overall percentage, and morning/afternoon/evening
/// adherence. This is pure calculation — no Firestore, no dart:io, no
/// PDF drawing — so it can be unit tested with a plain list of
/// [DoseLogEntry] and no Firebase setup at all.
///
/// This logic used to live inline inside `PdfExportService.exportAdherenceReports`
/// in the old `pdf_export_provider.dart`, mixed in with the Firestore query
/// and the PDF layout code. The math itself is unchanged from that version.
class BuildAdherenceReport {
  const BuildAdherenceReport();

  AdherenceReportData call({
    required List<DoseLogEntry> logs,
    required String reportLabel,
    required String patientName,
    required int expectedTotalDoses,
    required int dosesPerDay,
    required DateTime periodStart,
    required int daysInPeriod,
    required List<MedicationScheduleEntry> medicationSchedule,
  }) {
    final int completedDoses = logs.where((l) => l.isCompleted).length;
    // The denominator is the *theoretical* number of doses that should
    // have occurred over the reporting period (days elapsed x doses per
    // day — see `computeExpectedTotalDoses`), not just how many happen to
    // have a log entry. A scheduling/logging gap shouldn't quietly shrink
    // the total and inflate the percentage — e.g. 2 medications/day for a
    // full 30-day month is 60 expected doses, period, regardless of how
    // many of those actually ended up logged. Defensively floored at
    // `completedDoses` in case the expected count is ever computed lower
    // than what's actually confirmed (e.g. a medication was added after
    // the period's "expected" snapshot was taken) — a report should never
    // claim more doses were taken than it says were possible.
    final int totalDoses =
        expectedTotalDoses < completedDoses ? completedDoses : expectedTotalDoses;
    final int missedDoses = totalDoses - completedDoses;
    // NOTE: uses .toInt() (truncation), matching the original
    // `PdfExportService.exportAdherenceReports` calculation exactly —
    // not .round(), which would give a different number for values
    // like 66.7%.
    final int overallPercent =
        totalDoses > 0 ? ((completedDoses / totalDoses) * 100).toInt() : 0;

    final morning = logs.where((l) => _isInWindow(l.reminderTime, 5, 12));
    final afternoon = logs.where((l) => _isInWindow(l.reminderTime, 12, 18));
    // Evening wraps past midnight: >=18 or <5 — same as `!isInWindow(5, 18)`.
    final evening = logs.where((l) => !_isInWindow(l.reminderTime, 5, 18));

    return AdherenceReportData(
      reportLabel: reportLabel,
      patientName: patientName,
      generatedAt: DateTime.now(),
      totalDoses: totalDoses,
      completedDoses: completedDoses,
      missedDoses: missedDoses,
      overallAdherencePercent: overallPercent,
      dosesPerDay: dosesPerDay,
      periodStart: periodStart,
      daysInPeriod: daysInPeriod,
      medicationSchedule: medicationSchedule,
      morningAdherence: _adherenceFraction(morning),
      afternoonAdherence: _adherenceFraction(afternoon),
      eveningAdherence: _adherenceFraction(evening),
      logs: logs,
    );
  }

  /// The permanent history collection only has data up to "now", so a
  /// month that's still in progress should only be queried up to today —
  /// except on the 1st of the month, when "this month" has no data yet
  /// and the caller actually means "last month, in full"
  /// (see `PatientProfileScreen._generateDynamicReportMonths`, which picks
  /// the target month to pair with this).
  DateTime resolveQueryEnd(DateTime now) {
    return now.day == 1
        ? DateTime(now.year, now.month, 1)
        : DateTime(now.year, now.month, now.day);
  }

  double _adherenceFraction(Iterable<DoseLogEntry> bucket) {
    final list = bucket.toList();
    if (list.isEmpty) return 0.0;
    return list.where((l) => l.isCompleted).length / list.length;
  }

  bool _isInWindow(String reminderTime, int startHour, int endHourExclusive) {
    final hour = _parseHour(reminderTime);
    return hour >= startHour && hour < endHourExclusive;
  }

  int _parseHour(String timeStr) {
    try {
      final cleanTime = timeStr.toUpperCase().trim();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
      final parts = rawTimeStr.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0].trim());
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return hour;
      }
    } catch (_) {
      // Fall through to the default below.
    }
    return 0;
  }
}