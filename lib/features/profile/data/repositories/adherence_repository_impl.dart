// lib/features/profile/data/repositories/adherence_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/adherence_report.dart';
import '../../domain/repositories/adherence_repository.dart';

/// Firestore-backed implementation. Reads from `medication_logs`, the
/// permanent history collection also written to by the medication
/// management feature (`timeline_provider.dart` / `medication_sync_service.dart`).
/// That collection is shared across features in this app today — see the
/// note in the module summary about feature boundaries.
class AdherenceRepositoryImpl implements AdherenceRepository {
  AdherenceRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<DoseLogEntry>> fetchLogs({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshot = await _firestore
        .collection('medication_logs')
        .where('userId', isEqualTo: patientId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('timestamp', isLessThan: Timestamp.fromDate(to))
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final bool isCompleted =
          data['status']?.toString().toLowerCase().contains('completed') ??
          false;
      // NOTE: the writers (`MedicationScheduleRepositoryImpl.markAsTaken`
      // and `MedicationStatusRepositoryImpl.markAsMissed`) save the dose
      // time under `time` and the log moment under `timestamp` — not
      // `reminderTime`/`takenAt`/`createdAt`. Those fields were never
      // actually written, so every entry used to silently fall back to
      // "right now" and "00:00", making every dose in a report look like
      // it happened at midnight on whatever day the report was generated.
      final Timestamp? ts = data['timestamp'] as Timestamp?;

      return DoseLogEntry(
        timestamp: ts?.toDate() ?? DateTime.now(),
        reminderTime: data['time'] ?? '00:00',
        medicationName: data['medicationName'] ?? 'N/A',
        isCompleted: isCompleted,
      );
    }).toList();
  }
}