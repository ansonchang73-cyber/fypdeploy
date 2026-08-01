// lib/features/caregiver_dashboard/data/repositories/adherence_reports_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/adherence_report_summary.dart';
import '../../domain/repositories/adherence_reports_repository.dart';

class AdherenceReportsRepositoryImpl implements AdherenceReportsRepository {
  AdherenceReportsRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<AdherenceReportSummary>> getReportsForPatient(String patientId) async {
    // Removed .orderBy('generatedAt') to avoid requiring a composite
    // Firestore index (patientId + generatedAt). Results are sorted
    // in-memory instead.
    final snapshot = await _firestore
        .collection('adherence_reports')
        .where('patientId', isEqualTo: patientId)
        .get();

    final reports = snapshot.docs.map((doc) {
      final data = doc.data();
      final Timestamp? ts = data['generatedAt'] as Timestamp?;

      return AdherenceReportSummary(
        id: doc.id,
        reportLabel: data['reportLabel'] ?? 'Adherence Report',
        downloadUrl: data['downloadUrl'] ?? '',
        generatedAt: ts?.toDate() ?? DateTime.now(),
      );
    }).toList();

    // Sort by generatedAt ascending (earliest first) in-memory.
    reports.sort((a, b) => a.generatedAt.compareTo(b.generatedAt));
    return reports;
  }
}
