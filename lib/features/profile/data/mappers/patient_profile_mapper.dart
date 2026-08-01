// lib/features/profile/data/mappers/patient_profile_mapper.dart
import '../../domain/entities/patient_profile.dart';

/// Converts between the raw Firestore `users/{uid}` document map and the
/// pure [PatientProfile] domain entity. This is the ONLY place that knows
/// the Firestore field names for a patient profile.
class PatientProfileMapper {
  const PatientProfileMapper._();

  static PatientProfile fromFirestore(String userId, Map<String, dynamic> data) {
    return PatientProfile(
      id: userId,
      fullName: data['fullName'] ?? data['name'] ?? 'Unknown Patient',
      avatarUrl: data['avatarUrl'] ?? 'https://i.pravatar.cc/150?img=11',
      gender: data['gender'] ?? 'Not Specified',
      age: data['age'] ?? 0,
      bloodType: data['bloodType'] ?? 'Unknown',
      email: data['email'] ?? 'No Email Provided',
      phone: data['phone'] ?? '',
      primaryDoctor: data['primaryDoctor'] ?? '',
      doctorContact: data['doctorContact'] ?? '',
      allergies: data['allergies'] ?? '',
      emergencyContactName: data['emergencyContactName'] ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] ?? '',
    );
  }
}