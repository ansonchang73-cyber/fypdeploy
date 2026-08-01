// lib/features/profile/data/repositories/linked_caregivers_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/linked_caregiver_summary.dart';
import '../../domain/repositories/linked_caregivers_repository.dart';
import '../../domain/repositories/shared_access_repository.dart';

/// Composes [SharedAccessRepository] for the actual link data (it already
/// owns that bidirectional schema), then does a lightweight `users/{id}`
/// read per linked caregiver for the name and avatar this screen needs —
/// same shape as `caregiver_dashboard`'s `LinkedPatientsRepositoryImpl`,
/// just mirrored for the other direction.
class LinkedCaregiversRepositoryImpl implements LinkedCaregiversRepository {
  LinkedCaregiversRepositoryImpl(this._sharedAccessRepository, this._firestore);

  final SharedAccessRepository _sharedAccessRepository;
  final FirebaseFirestore _firestore;

  @override
  Future<List<LinkedCaregiverSummary>> getLinkedCaregivers(String patientId) async {
    final caregiverIds = await _sharedAccessRepository.getTrustedUsers(patientId);

    final summaries = <LinkedCaregiverSummary>[];
    for (final caregiverId in caregiverIds) {
      final doc = await _firestore.collection('users').doc(caregiverId).get();
      final data = doc.data();

      summaries.add(
        LinkedCaregiverSummary(
          id: caregiverId,
          fullName: data?['fullName'] ?? data?['name'] ?? 'Unknown Caregiver',
          avatarUrl: data?['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=12',
          phone: data?['phone'] ?? data?['phoneNumber'] ?? '',
        ),
      );
    }

    return summaries;
  }
}
