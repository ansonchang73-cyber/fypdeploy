// lib/features/profile/domain/repositories/care_circle_repository.dart
import '../entities/care_member.dart';

abstract class CareCircleRepository {
  Future<List<CareMember>> getCareCircle();
}