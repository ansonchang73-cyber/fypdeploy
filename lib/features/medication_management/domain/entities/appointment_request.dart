// lib/features/medication_management/domain/entities/appointment_request.dart

/// What the appointment form collects. This feature only ever *writes*
/// an appointment (it doesn't read/display existing ones the way
/// `profile` and `system_health` do), so there's no need for a full
/// `Appointment` read entity here — just the write shape.
class AppointmentRequest {
  final String title;
  final String doctorName;
  final String location;
  final DateTime dateTime;

  const AppointmentRequest({
    required this.title,
    required this.doctorName,
    required this.location,
    required this.dateTime,
  });
}

/// Previously-used doctor names and locations, offered as autocomplete
/// suggestions when booking a new appointment.
class AppointmentSuggestions {
  final List<String> doctorNames;
  final List<String> locations;

  const AppointmentSuggestions({
    required this.doctorNames,
    required this.locations,
  });
}
