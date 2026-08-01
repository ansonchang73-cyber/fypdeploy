// lib/features/adherence_analytics/domain/usecases/build_adherence_summary.dart
import '../entities/adherence_summary.dart';

/// Turns a list of dose records into an [AdherenceSummary]: completion
/// percentage, adherence tier, and morning/afternoon/evening breakdown.
/// Pure calculation — no Flutter, no Firestore — so it's unit-testable
/// with a plain list of [DoseRecord].
///
/// This is the THIRD copy of this exact percentage/time-bucketing pattern
/// found in the codebase — the same math (down to the hour-parsing
/// helper) was duplicated in `pdf_export_provider.dart` (profile feature,
/// already extracted into `BuildAdherenceReport`) and lives again, still
/// inline, inside `medication_management`'s daily-reset logic. Worth
/// promoting to one shared implementation (e.g. under `lib/core/`) once
/// medication_management is refactored too, rather than maintaining a
/// fourth copy — see the module summary for details.
class BuildAdherenceSummary {
  const BuildAdherenceSummary();

  AdherenceSummary call(List<DoseRecord> doses) {
    final int totalDoses = doses.length;
    final int completedDoses = doses.where((d) => d.isCompleted).length;
    final int overallPercent =
        totalDoses > 0 ? ((completedDoses / totalDoses) * 100).toInt() : 0;

    final morning = doses.where((d) => _isInWindow(d.time, 5, 12));
    final afternoon = doses.where((d) => _isInWindow(d.time, 12, 18));
    // Evening wraps past midnight: >=18 or <5 — same as `!isInWindow(5, 18)`.
    final evening = doses.where((d) => !_isInWindow(d.time, 5, 18));

    return AdherenceSummary(
      totalDoses: totalDoses,
      completedDoses: completedDoses,
      overallAdherencePercent: overallPercent,
      tier: _tierFor(overallPercent),
      morningAdherence: _adherenceFraction(morning),
      afternoonAdherence: _adherenceFraction(afternoon),
      eveningAdherence: _adherenceFraction(evening),
    );
  }

  AdherenceTier _tierFor(int overallPercent) {
    if (overallPercent >= 80) return AdherenceTier.excellent;
    if (overallPercent >= 50) return AdherenceTier.good;
    return AdherenceTier.needsAttention;
  }

  double _adherenceFraction(Iterable<DoseRecord> bucket) {
    final list = bucket.toList();
    if (list.isEmpty) return 0.0;
    return list.where((d) => d.isCompleted).length / list.length;
  }

  bool _isInWindow(String time, int startHour, int endHourExclusive) {
    final hour = _parseHour(time);
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
        if (isPM && hour < 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }
        return hour;
      }
    } catch (_) {
      // Fall through to the default below.
    }
    return 0;
  }
}
