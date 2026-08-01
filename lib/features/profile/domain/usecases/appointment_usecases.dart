// lib/features/profile/domain/usecases/appointment_usecases.dart
import '../entities/appointment.dart';
import '../repositories/patient_repository.dart';

class WatchAppointments {
  const WatchAppointments(this._repository);
  final PatientRepository _repository;

  Stream<List<Appointment>> call(String userId, {required bool isUpcoming}) =>
      _repository.watchAppointments(userId, isUpcoming: isUpcoming);
}