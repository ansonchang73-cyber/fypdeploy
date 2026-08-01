// lib/features/profile/domain/entities/care_member.dart
enum MemberType { family, medical }

enum MemberStatus { active, pending, systemInCare }

class CareMember {
  final String id;
  final String name;
  final String role;
  final MemberType type;
  final MemberStatus status;
  final String avatarUrl;

  const CareMember({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    this.status = MemberStatus.active,
    required this.avatarUrl,
  });
}