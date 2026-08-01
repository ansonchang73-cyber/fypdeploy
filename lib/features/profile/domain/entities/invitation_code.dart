// lib/features/profile/domain/entities/invitation_code.dart
//
// Replaces the old `Map<String, dynamic>{"code": ..., "expiresAt": ...}`
// shape with a typed value object, so callers get compile-time checking
// instead of hoping the map keys are spelled right.
class InvitationCode {
  final String code;
  final DateTime expiresAt;

  const InvitationCode({required this.code, required this.expiresAt});
}