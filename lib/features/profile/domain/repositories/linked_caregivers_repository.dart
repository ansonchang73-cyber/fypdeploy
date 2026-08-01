// lib/features/profile/domain/repositories/linked_caregivers_repository.dart
import '../entities/linked_caregiver_summary.dart';

abstract class LinkedCaregiversRepository {
  /// Every caregiver who has redeemed an invitation code linking them to
  /// [patientId] — see `SharedAccessRepository.getTrustedUsers`, which
  /// this composes with rather than duplicating.
  Future<List<LinkedCaregiverSummary>> getLinkedCaregivers(String patientId);
}
