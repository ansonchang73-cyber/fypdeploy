// lib/features/profile/domain/repositories/adherence_reports_repository.dart
import 'dart:typed_data';

/// Write side of the shared `adherence_reports` Firestore collection +
/// Firebase Storage bucket: this is where a generated report gets
/// published so it's visible outside the device that made it — to a
/// caregiver, for instance. The read side lives in `caregiver_dashboard`,
/// which has no reason to depend on this feature's domain layer for a
/// collection both features just happen to touch, the same way
/// `appointments` is treated elsewhere in this app.
abstract class AdherenceReportsRepository {
  /// Uploads [pdfBytes] to Storage and records its metadata in Firestore
  /// under [patientId], labeled [reportLabel]. Best-effort: callers
  /// should not let a failure here block the local save the PDF already
  /// got — see `ReportExportController`.
  Future<void> publishReport({
    required String patientId,
    required String reportLabel,
    required String fileName,
    required Uint8List pdfBytes,
  });
}
