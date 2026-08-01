// lib/features/caregiver_dashboard/domain/entities/adherence_report_summary.dart

/// Read-side view of one entry in the shared `adherence_reports`
/// Firestore collection (`profile` writes to it when a patient exports a
/// report; see that feature's `AdherenceReportsRepository`).
class AdherenceReportSummary {
  final String id;
  final String reportLabel;
  final String downloadUrl;
  final DateTime generatedAt;

  const AdherenceReportSummary({
    required this.id,
    required this.reportLabel,
    required this.downloadUrl,
    required this.generatedAt,
  });
}
