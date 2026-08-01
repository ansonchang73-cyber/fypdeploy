// lib/features/system_health/domain/repositories/system_health_repository.dart
import '../entities/system_health_state.dart';

abstract class SystemHealthRepository {
  Stream<SystemHealthState> watchSystemHealth(String userId);
}
