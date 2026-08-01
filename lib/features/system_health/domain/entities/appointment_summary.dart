// lib/features/system_health/domain/entities/appointment_summary.dart
//
// A small, feature-local view of an appointment — the same underlying
// Firestore collection as `profile`'s `Appointment` entity, but this
// feature only ever needs these four fields for its "next 2 upcoming"
// widget. Not importing `profile`'s domain layer here on purpose: a
// system_health -> profile dependency would be a backwards, arbitrary
// coupling between two peer features. See the module summary for the
// note on consolidating appointment access later.
class AppointmentSummary {
  final String id;
  final String title;
  final String doctorName;
  final String location;
  final DateTime dateTime;

  const AppointmentSummary({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.location,
    required this.dateTime,
  });
}
