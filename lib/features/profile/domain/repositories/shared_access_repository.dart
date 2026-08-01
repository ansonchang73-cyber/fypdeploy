// lib/features/profile/domain/repositories/shared_access_repository.dart
import '../entities/alert.dart';
import '../entities/invitation_code.dart';

/// =======================================================
/// Shared Access Repository (Domain Contract)
/// =======================================================
abstract class SharedAccessRepository {
  // =============================
  // ALERT ID
  // =============================
  String generateAlertId();

  // =============================
  // INVITATION CODES
  // =============================
  Future<InvitationCode> createInvitationCode({required String elderlyUserId});

  Future<InvitationCode?> getActiveInvitationCode(String elderlyUserId);

  Future<String> validateAndConsumeInvitationCode(String code);

  // =============================
  // TRUSTED ACCESS
  // =============================
  Future<void> linkTrustedUser({
    required String elderlyUserId,
    required String trustedUserId,
  });

  Future<List<String>> getLinkedElderlyUsers(String trustedUserId);

  Future<List<String>> getTrustedUsers(String elderlyUserId);

  Future<void> removeTrustedUser({
    required String elderlyUserId,
    required String trustedUserId,
  });

  // =============================
  // 🔔 ALERTS
  // =============================
  Future<void> createAlert(Alert alert);

  /// ⚠️ Existing (general-purpose, keep for compatibility)
  Future<int> countAlerts({
    required String elderlyUserId,
    required DateTime since,
  });

  /// ✅ Count spending-limit alerts for today only
  Future<int> countSpendingLimitAlertsForToday({
    required String elderlyUserId,
    required DateTime since,
  });

  Future<List<Alert>> getAlertsForTrustedUser({required String trustedUserId});

  // =============================
  // USER INFO
  // =============================
  Future<String> getElderlyName(String elderlyUserId);

  Future<Map<String, dynamic>> getUserData(String userId);
}