// lib/features/caregiver_dashboard/domain/repositories/linked_patients_repository.dart
import '../entities/linked_patient_summary.dart';

abstract class LinkedPatientsRepository {
  /// Every patient who has linked [caregiverId] as a trusted caregiver,
  /// via the invitation-code flow in `profile`.
  Future<List<LinkedPatientSummary>> getLinkedPatients(String caregiverId);
}
