// lib/features/profile/data/mappers/appointment_mapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/appointment.dart';

/// Converts between a raw Firestore `appointments/{id}` document and the
/// pure [Appointment] domain entity. This is the only file in the profile
/// feature allowed to import `cloud_firestore` just to read a document —
/// the repository implementation calls into this, not the other way round.
class AppointmentMapper {
  const AppointmentMapper._();

  static Appointment fromFirestore(String id, Map<String, dynamic> data) {
    return Appointment(
      id: id,
      title: data['title'] ?? 'Medical Appointment',
      doctorName: data['doctorName'] ?? 'Unknown Doctor',
      location: data['location'] ?? 'Unknown Location',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
    );
  }
}