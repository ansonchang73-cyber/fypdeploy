// lib/features/profile/domain/usecases/patient_profile_usecases.dart
import '../entities/patient_profile.dart';
import '../repositories/patient_repository.dart';

/// These three are thin delegations to [PatientRepository] — there's no
/// business rule beyond "call the repository". They still get their own
/// use case classes (rather than letting the UI call the repository
/// directly) so the presentation layer only ever depends on `domain/`,
/// never on `data/` or `cloud_firestore`.
class WatchPatientProfile {
  const WatchPatientProfile(this._repository);
  final PatientRepository _repository;

  Stream<PatientProfile> call(String userId) =>
      _repository.watchPatientProfile(userId);
}

class UpdatePatientProfile {
  const UpdatePatientProfile(this._repository);
  final PatientRepository _repository;

  Future<void> call(String userId, Map<String, dynamic> updates) =>
      _repository.updateProfile(userId, updates);
}

class UpdatePatientAvatar {
  const UpdatePatientAvatar(this._repository);
  final PatientRepository _repository;

  Future<void> call(String userId, String avatarDataUrl) =>
      _repository.updateAvatar(userId, avatarDataUrl);
}