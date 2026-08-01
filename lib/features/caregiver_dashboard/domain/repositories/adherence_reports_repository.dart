// lib/features/caregiver_dashboard/domain/repositories/adherence_reports_repository.dart
import '../entities/adherence_report_summary.dart';

/// Read side of the shared `adherence_reports` collection. See
/// `profile`'s `AdherenceReportsRepository` (the write side) for where
/// these documents come from — this feature only ever reads them.
abstract class AdherenceReportsRepository {
  /// [patientId]'s reports, earliest first.
  Future<List<AdherenceReportSummary>> getReportsForPatient(String patientId);
}
