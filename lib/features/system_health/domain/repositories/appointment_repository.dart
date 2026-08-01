// lib/features/system_health/domain/repositories/appointment_repository.dart
import '../entities/appointment_summary.dart';

abstract class AppointmentRepository {
  /// The [limit] most distant upcoming appointments — matches the
  /// original screen's behavior exactly (descending sort, so this
  /// returns the *furthest-out* appointments, not the soonest). Kept
  /// as-is; see the module summary.
  Stream<List<AppointmentSummary>> watchUpcomingAppointments(
    String userId, {
    required int limit,
  });
}
