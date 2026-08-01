// lib/features/profile/domain/usecases/get_linked_caregivers.dart
import '../entities/linked_caregiver_summary.dart';
import '../repositories/linked_caregivers_repository.dart';

class GetLinkedCaregivers {
  const GetLinkedCaregivers(this._repository);
  final LinkedCaregiversRepository _repository;

  Future<List<LinkedCaregiverSummary>> call(String patientId) =>
      _repository.getLinkedCaregivers(patientId);
}
