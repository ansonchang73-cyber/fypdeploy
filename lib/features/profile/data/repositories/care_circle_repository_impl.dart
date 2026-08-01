// lib/features/profile/data/repositories/care_circle_repository_impl.dart
import '../../domain/entities/care_member.dart';
import '../../domain/repositories/care_circle_repository.dart';

/// ⚠️ Still a hardcoded/mock implementation, carried over unchanged from
/// the old `careCircleProvider`. It is NOT wired to Firestore — there is
/// no real "care circle members" collection in this project yet (the
/// actual caregiver-linking data lives under `shared_access` /
/// `trusted_access`, handled by [SharedAccessRepository] instead). This
/// class exists so that when a real backing store is added, only this one
/// file needs to change — nothing in `domain/` or `presentation/` will
/// need to know.
class CareCircleRepositoryImpl implements CareCircleRepository {
  @override
  Future<List<CareMember>> getCareCircle() async {
    return [
      // TODO: MAKE IT NOT HARDCODED ANYMORE
      CareMember(
        id: '1',
        name: 'Robert Jenkins',
        role: 'PRIMARY GUARDIAN',
        type: MemberType.family,
        avatarUrl: 'https://i.pravatar.cc/150?img=11',
      ),
      CareMember(
        id: '2',
        name: 'David Jenkins',
        role: 'SECONDARY CONTACT',
        type: MemberType.family,
        avatarUrl: 'https://i.pravatar.cc/150?img=12',
      ),
      CareMember(
        id: '3',
        name: 'Dr. Aris Thorne',
        role: 'NEUROLOGIST',
        type: MemberType.medical,
        status: MemberStatus.systemInCare,
        avatarUrl: 'https://i.pravatar.cc/150?img=13',
      ),
      CareMember(
        id: '4',
        name: 'Sarah Miller, NP',
        role: 'CARE MANAGER',
        type: MemberType.medical,
        avatarUrl: 'https://i.pravatar.cc/150?img=14',
      ),
    ];
  }
}