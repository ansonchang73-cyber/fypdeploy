// lib/features/profile/presentation/providers/report_export_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/adherence_report.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/merge_live_overdue_doses.dart';
import 'profile_providers.dart';

/// Presentation-layer orchestration for "export a PDF" actions. It has no
/// Firestore calls of its own and no adherence math of its own — it just
/// sequences collaborators from lower layers: [adherenceRepositoryProvider]
/// (data) to fetch raw logs, [buildAdherenceReportProvider] (domain) to turn
/// them into a report, [pdfReportRendererProvider] (data/infrastructure)
/// to draw and save the PDF, and — for adherence reports specifically —
/// [adherenceReportsRepositoryProvider] to publish a copy to Storage so a
/// caregiver can see it too.
///
/// This replaces `PdfExportService` from the old `providers/pdf_export_provider.dart`,
/// which used to do the Firestore query, the percentage math, AND the PDF
/// drawing all in one class.
class ReportExportController {
  ReportExportController(this._ref);
  final Ref _ref;

  Future<List<String>> exportAdherenceReports({
    required String patientId,
    required String patientName,
    required List<String> chosenReports,
    required Map<String, DateTime> reportTargetMonths,
  }) async {
    final adherenceRepository = _ref.read(adherenceRepositoryProvider);
    final buildReport = _ref.read(buildAdherenceReportProvider);
    final renderer = _ref.read(pdfReportRendererProvider);
    final reportsRepository = _ref.read(adherenceReportsRepositoryProvider);

    final List<String> savedPaths = [];

    for (final reportName in chosenReports) {
      final targetMonth = reportTargetMonths[reportName]!;
      final queryEnd = buildReport.resolveQueryEnd(DateTime.now());

      final logs = await adherenceRepository.fetchLogs(
        patientId: patientId,
        from: targetMonth,
        to: queryEnd,
      );

      // Fetched once, shared by the three things below that all need it:
      // today's live overdue-dose check, the theoretical expected-dose
      // count, and the "your medications, at these times" listing.
      final schedule = await fetchDailySchedule(_ref, patientId);

      // Same correction as the caregiver Storage page's monthly card:
      // without this, a month "so far" only reflects doses the patient
      // has explicitly confirmed, which can look far better than reality
      // until the next day's reset catches up.
      final mergedLogs = queryWindowCoversToday(targetMonth, queryEnd)
          ? [...logs, ...liveOverdueEntriesForToday(schedule, logs)]
          : logs;

      final daysInPeriod = daysInReportPeriod(targetMonth);

      final report = buildReport(
        logs: mergedLogs,
        reportLabel: reportName,
        patientName: patientName,
        expectedTotalDoses: expectedTotalDosesFor(schedule, daysInPeriod),
        dosesPerDay: schedule.length,
        periodStart: targetMonth,
        daysInPeriod: daysInPeriod,
        medicationSchedule: sortedMedicationSchedule(schedule),
      );

      final result = await renderer.renderAdherenceReport(report);
      savedPaths.add(result.path);

      // Best-effort: a caregiver not being able to see this report yet
      // shouldn't stop the patient from getting their local copy, which
      // already succeeded above.
      try {
        final safeFilename =
            '${reportName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
        await reportsRepository.publishReport(
          patientId: patientId,
          reportLabel: reportName,
          fileName: safeFilename,
          pdfBytes: result.bytes,
        );
      } catch (e) {
        debugPrint('Failed to publish report to Storage: $e');
      }
    }

    return savedPaths;
  }

  Future<String> exportAppointmentRecord(
    Appointment appointment,
    String fileName, {
    required String patientId,
    required String patientName,
  }) async {
    // Every appointment record now also carries the adherence data for
    // the calendar month it fell in — since this is always a *past*
    // appointment, that month's data already exists, and a doctor
    // reviewing the visit cares how the patient was doing in the lead-up
    // to it, not just the visit details on their own.
    final adherenceRepository = _ref.read(adherenceRepositoryProvider);
    final buildReport = _ref.read(buildAdherenceReportProvider);

    final apptDate = appointment.dateTime;
    final monthStart = DateTime(apptDate.year, apptDate.month, 1);
    final nextMonthStart = DateTime(apptDate.year, apptDate.month + 1, 1);
    final now = DateTime.now();
    // If the appointment's month has already fully elapsed, report the
    // full month. If the appointment happened earlier in the *current*
    // month, report "so far" instead — there's no data past today yet.
    final bool monthComplete = !now.isBefore(nextMonthStart);
    final DateTime queryEnd =
        monthComplete ? nextMonthStart : buildReport.resolveQueryEnd(now);
    final periodLabel = adherenceReportLabelForMonth(monthStart);

    AdherenceReportData? monthlyAdherence;
    try {
      final logs = await adherenceRepository.fetchLogs(
        patientId: patientId,
        from: monthStart,
        to: queryEnd,
      );
      // Same correction as everywhere else this data shows up: without
      // this, "so far this month" only reflects doses the patient has
      // explicitly confirmed.
      final schedule = await fetchDailySchedule(_ref, patientId);
      final mergedLogs = queryWindowCoversToday(monthStart, queryEnd)
          ? [...logs, ...liveOverdueEntriesForToday(schedule, logs)]
          : logs;
      final daysInPeriod = daysInReportPeriod(monthStart);
      monthlyAdherence = buildReport(
        logs: mergedLogs,
        reportLabel: periodLabel,
        patientName: patientName,
        expectedTotalDoses: expectedTotalDosesFor(schedule, daysInPeriod),
        dosesPerDay: schedule.length,
        periodStart: monthStart,
        daysInPeriod: daysInPeriod,
        medicationSchedule: sortedMedicationSchedule(schedule),
      );
    } catch (e) {
      // Best-effort, same philosophy as the Storage-publish step in
      // exportAdherenceReports above: a failure here shouldn't block the
      // appointment record itself from being generated.
      debugPrint('Failed to load monthly adherence for appointment record: $e');
    }

    return _ref.read(pdfReportRendererProvider).renderAppointmentRecord(
          appointment,
          fileName: fileName,
          monthlyAdherence: monthlyAdherence,
        );
  }
}

final reportExportControllerProvider = Provider<ReportExportController>((ref) {
  return ReportExportController(ref);
});
