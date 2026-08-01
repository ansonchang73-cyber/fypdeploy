// lib/features/profile/domain/entities/patient_profile.dart
//
// Pure domain entity. Deliberately has ZERO imports from Flutter or
// Firebase — this is what makes it usable/testable from anywhere,
// including plain `dart test` with no widget or Firestore setup.
// Firestore <-> PatientProfile conversion lives in
// `data/mappers/patient_profile_mapper.dart`, not here.
class PatientProfile {
  final String id;
  final String fullName;
  final String avatarUrl;
  final String gender;
  final int age;
  final String bloodType;
  final String email;
  final String phone;
  final String primaryDoctor;
  final String doctorContact;
  final String allergies;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.gender,
    required this.age,
    required this.bloodType,
    required this.email,
    required this.phone,
    required this.primaryDoctor,
    required this.doctorContact,
    required this.allergies,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });
}