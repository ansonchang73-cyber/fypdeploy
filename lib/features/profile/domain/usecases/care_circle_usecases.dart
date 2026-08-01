// lib/features/profile/domain/usecases/care_circle_usecases.dart
import '../entities/care_member.dart';
import '../repositories/care_circle_repository.dart';

class GetCareCircle {
  const GetCareCircle(this._repository);
  final CareCircleRepository _repository;

  Future<List<CareMember>> call() => _repository.getCareCircle();
}