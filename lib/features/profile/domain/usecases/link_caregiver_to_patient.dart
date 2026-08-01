// lib/features/profile/domain/usecases/link_caregiver_to_patient.dart
import '../repositories/shared_access_repository.dart';

/// The redeem half of the invitation-code system — [GenerateInvitationCode]
/// (in this same folder) makes a code from the patient's side;
/// this consumes it from the caregiver's side. Both steps were already
/// implemented on [SharedAccessRepository] but nothing in the app ever
/// called them.
///
/// Validates and consumes [invitationCode], then links whichever patient
/// it belonged to with [caregiverUserId]. Throws with one of
/// `INVALID_CODE`, `CODE_USED`, or `CODE_EXPIRED` in the message if the
/// code doesn't check out — see `SharedAccessRepositoryImpl.validateAndConsumeInvitationCode`.
class LinkCaregiverToPatient {
  const LinkCaregiverToPatient(this._repository);
  final SharedAccessRepository _repository;

  Future<void> call({
    required String invitationCode,
    required String caregiverUserId,
  }) async {
    final elderlyUserId = await _repository.validateAndConsumeInvitationCode(
      invitationCode,
    );

    await _repository.linkTrustedUser(
      elderlyUserId: elderlyUserId,
      trustedUserId: caregiverUserId,
    );
  }
}
