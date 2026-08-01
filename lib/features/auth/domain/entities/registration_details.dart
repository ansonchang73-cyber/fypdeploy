// lib/features/auth/domain/entities/registration_details.dart
import 'user_role.dart';

/// What the registration form collects. `age` stays a raw string here,
/// same as the original — parsing (and defaulting to 0) happens where
/// the Firestore document is built, not before.
class RegistrationDetails {
  final String email;
  final String password;
  final UserRole role;
  final String fullName;
  final String age;
  final String gender;
  final String bloodType;

  const RegistrationDetails({
    required this.email,
    required this.password,
    required this.role,
    required this.fullName,
    this.age = '',
    this.gender = '',
    this.bloodType = '',
  });
}
