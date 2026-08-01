// lib/features/profile/domain/entities/appointment.dart
//
// Pure domain entity — uses plain DateTime, not Firestore's Timestamp.
// The Timestamp <-> DateTime conversion lives in
// `data/mappers/appointment_mapper.dart`.
class Appointment {
  final String id;
  final String title;
  final String doctorName;
  final String location;
  final DateTime dateTime;

  const Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.location,
    required this.dateTime,
  });
}