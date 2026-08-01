// lib/features/profile/domain/usecases/generate_invitation_code.dart
import '../entities/invitation_code.dart';
import '../repositories/shared_access_repository.dart';

class GenerateInvitationCode {
  const GenerateInvitationCode(this.repository);
  final SharedAccessRepository repository;

  Future<InvitationCode> call({required String elderlyUserId}) {
    return repository.createInvitationCode(elderlyUserId: elderlyUserId);
  }
}