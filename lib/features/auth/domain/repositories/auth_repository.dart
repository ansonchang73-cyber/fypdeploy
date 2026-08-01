// lib/features/auth/domain/repositories/auth_repository.dart
import '../entities/registration_details.dart';

abstract class AuthRepository {
  /// No role parameter — the original only ever used `role` to echo it
  /// back into presentation state on success, never sent it to Firebase
  /// Auth itself. That echo-back stays in the controller; this is just
  /// the actual sign-in operation.
  Future<void> login(String email, String password);

  Future<void> register(RegistrationDetails details);

  Future<void> logout();
}
