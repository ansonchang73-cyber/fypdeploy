// lib/features/medication_management/domain/repositories/appointment_repository.dart
import '../entities/appointment_request.dart';

abstract class AppointmentRepository {
  Future<void> createAppointment(String userId, AppointmentRequest request);

  /// Distinct doctor names / locations from this user's past
  /// appointments, for the booking form's autocomplete.
  Future<AppointmentSuggestions> fetchSuggestions(String userId);
}
