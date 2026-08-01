// lib/features/caregiver_dashboard/domain/usecases/caregiver_dashboard_usecases.dart
import '../entities/adherence_report_summary.dart';
import '../entities/linked_patient_summary.dart';
import '../repositories/adherence_reports_repository.dart';
import '../repositories/linked_patients_repository.dart';

class GetLinkedPatients {
  const GetLinkedPatients(this._repository);
  final LinkedPatientsRepository _repository;

  Future<List<LinkedPatientSummary>> call(String caregiverId) =>
      _repository.getLinkedPatients(caregiverId);
}

class GetAdherenceReportsForPatient {
  const GetAdherenceReportsForPatient(this._repository);
  final AdherenceReportsRepository _repository;

  Future<List<AdherenceReportSummary>> call(String patientId) =>
      _repository.getReportsForPatient(patientId);
}
