// lib/features/auth/presentation/providers/auth_controller.dart
//
// Public API unchanged from the old `providers/auth_provider.dart`:
// `authProvider`, `AuthState`, `selectedRoleProvider`, and `UserRole`
// (re-exported below) all keep their names and shapes — only the
// Firebase Auth/Firestore calls moved out, into `AuthRepositoryImpl`.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/registration_details.dart';
import '../../domain/entities/user_role.dart';
import 'auth_providers.dart';

// Screens only need to import this file to get UserRole too, same as
// when it lived directly inside the old auth_provider.dart.
export '../../domain/entities/user_role.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserRole userRole;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.userRole = UserRole.none,
  });

  /// NOTE: [errorMessage] can't just be `errorMessage ?? this.errorMessage`
  /// like the other fields — that makes it impossible to ever *clear* the
  /// error, since passing `null` (meaning "no error this time") is
  /// indistinguishable from "didn't touch this field". That was the bug:
  /// after one failed login, `errorMessage` got stuck forever, so even a
  /// *successful* later login still looked like a failure to any screen
  /// checking `errorMessage == null`. [clearError] gives callers an
  /// explicit way to say "yes, really set it back to null".
  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    UserRole? userRole,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userRole: userRole ?? this.userRole,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  /// [role] was never sent to Firebase Auth in the original either — it
  /// only ever got echoed straight back into state on success. Preserved
  /// exactly: the actual sign-in call (now via the [Login] use case)
  /// doesn't take it.
  Future<void> login(String email, String password, UserRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(loginProvider).call(email, password);
      state = state.copyWith(isLoading: false, userRole: role, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
    }
  }

  Future<void> register(
    String email,
    String password,
    UserRole role,
    String fullName, {
    String age = '',
    String gender = '',
    String bloodType = '',
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      await ref.read(registerProvider).call(
            RegistrationDetails(
              email: email,
              password: password,
              role: role,
              fullName: fullName,
              age: age,
              gender: gender,
              bloodType: bloodType,
            ),
          );

      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e),
      );
    }
  }

  /// Turns Firebase's `[firebase_auth/xyz] ...` exceptions into something
  /// readable to show under the form fields, instead of the raw
  /// `e.toString()` that used to leak straight to the UI.
  String _friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password. Please try again.';
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);

final selectedRoleProvider = StateProvider<UserRole>((ref) => UserRole.none);
