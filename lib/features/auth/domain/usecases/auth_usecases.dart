// lib/features/auth/domain/usecases/auth_usecases.dart
import '../entities/registration_details.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this._repository);
  final AuthRepository _repository;

  Future<void> call(String email, String password) =>
      _repository.login(email, password);
}

class Register {
  const Register(this._repository);
  final AuthRepository _repository;

  Future<void> call(RegistrationDetails details) =>
      _repository.register(details);
}

class Logout {
  const Logout(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
