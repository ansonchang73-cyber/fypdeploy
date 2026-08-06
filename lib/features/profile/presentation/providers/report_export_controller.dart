// lib/features/profile/presentation/providers/report_export_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/adherence_report.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/merge_live_overdue_doses.dart';
import 'profile_providers.dart';

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
      
      final now = DateTime.now();
      final bool isCurrentMonth = targetMonth.year == now.year && targetMonth.month == now.month;
      final DateTime nextMonthStart = DateTime(targetMonth.year, targetMonth.month + 1, 1);
      
      // Feature 2 Fix: Past months evaluate to their actual complete boundary, current month to now.
      final queryEnd = isCurrentMonth ? buildReport.resolveQueryEnd(now) : nextMonthStart;

      final logs = await adherenceRepository.fetchLogs(
        patientId: patientId,
        from: targetMonth,
        to: queryEnd,
      );

      final schedule = await fetchDailySchedule(_ref, patientId);

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

      try {
        final safeFilename = '${reportName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
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
    final adherenceRepository = _ref.read(adherenceRepositoryProvider);
    final buildReport = _ref.read(buildAdherenceReportProvider);

    final apptDate = appointment.dateTime;
    final monthStart = DateTime(apptDate.year, apptDate.month, 1);
    final nextMonthStart = DateTime(apptDate.year, apptDate.month + 1, 1);
    final now = DateTime.now();
    
    final bool monthComplete = !now.isBefore(nextMonthStart);
    final DateTime queryEnd = monthComplete ? nextMonthStart : buildReport.resolveQueryEnd(now);
    final periodLabel = adherenceReportLabelForMonth(monthStart);

    AdherenceReportData? monthlyAdherence;
    try {
      final logs = await adherenceRepository.fetchLogs(
        patientId: patientId,
        from: monthStart,
        to: queryEnd,
      );
      
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