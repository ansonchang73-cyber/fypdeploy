// lib/features/caregiver_dashboard/data/repositories/linked_patients_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../profile/domain/repositories/shared_access_repository.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../../domain/repositories/linked_patients_repository.dart';

/// Composes `profile`'s [SharedAccessRepository] for the actual
/// caregiver-to-patient link data (it already owns that bidirectional
/// `shared_access` / `trusted_access` schema — reimplementing it here
/// would just be a second, riskier copy of the same fragile structure),
/// then does a lightweight `users/{id}` read per linked patient for just
/// the name and avatar this feature needs to show a list.
class LinkedPatientsRepositoryImpl implements LinkedPatientsRepository {
  LinkedPatientsRepositoryImpl(this._sharedAccessRepository, this._firestore);

  final SharedAccessRepository _sharedAccessRepository;
  final FirebaseFirestore _firestore;

  @override
  Future<List<LinkedPatientSummary>> getLinkedPatients(String caregiverId) async {
    final patientIds = await _sharedAccessRepository.getLinkedElderlyUsers(
      caregiverId,
    );

    final summaries = <LinkedPatientSummary>[];
    for (final patientId in patientIds) {
      final doc = await _firestore.collection('users').doc(patientId).get();
      final data = doc.data();

      summaries.add(
        LinkedPatientSummary(
          id: patientId,
          fullName: data?['fullName'] ?? data?['name'] ?? 'Unknown Patient',
          avatarUrl: data?['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=11',
        ),
      );
    }

    return summaries;
  }
}
