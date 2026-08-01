// lib/features/profile/domain/repositories/patient_repository.dart
import '../entities/patient_profile.dart';
import '../entities/appointment.dart';

/// Contract for reading/writing a patient's profile and appointments.
/// The domain and presentation layers depend on this interface only —
/// never on `PatientRepositoryImpl` or `cloud_firestore` directly.
abstract class PatientRepository {
  Stream<PatientProfile> watchPatientProfile(String userId);

  Future<void> updateProfile(String userId, Map<String, dynamic> updates);

  Future<void> updateAvatar(String userId, String avatarDataUrl);

  Stream<List<Appointment>> watchAppointments(
    String userId, {
    required bool isUpcoming,
  });
}