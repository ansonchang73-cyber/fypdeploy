// lib/features/profile/presentation/providers/patient_profile_controller.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/patient_profile.dart';
import 'profile_providers.dart';

/// Presentation-layer controller: exposes the signed-in patient's profile
/// as an [AsyncValue] and offers the UI-facing update actions. It contains
/// no Firestore calls and no business logic of its own — both of those
/// live in the use cases it delegates to (`watchPatientProfileProvider`,
/// `updatePatientProfileProvider`, `updatePatientAvatarProvider`).
///
/// This replaces `PatientNotifier` from the old `providers/patient_provider.dart`,
/// which used to call `FirebaseFirestore.instance` directly here — a second,
/// slightly different copy of what `ProfileRepository` (also unused) already
/// did.
///
/// IMPORTANT: this is also the fix for the broken build. The old screens
/// (`patient_profile_screen.dart`, `settings_screen.dart`) were already
/// calling `ref.watch(patientProfileProvider)`, but nothing defined a
/// provider with that name — the old `patient_provider.dart` only exported
/// `patientProvider`. That mismatch is what produced the
/// "undefined identifier: patientProfileProvider" error. The provider
/// below is deliberately named `patientProfileProvider` so both screens'
/// existing `ref.watch(patientProfileProvider)` calls now resolve, and
/// `ref.read(patientProfileProvider.notifier).updateProfile(...)` /
/// `.updateAvatar(...)` work the same way `ref.read(patientProvider.notifier)...`
/// used to.
class PatientProfileController extends StateNotifier<AsyncValue<PatientProfile>> {
  PatientProfileController(this._ref) : super(const AsyncValue.loading()) {
    _subscribe();
  }

  final Ref _ref;
  StreamSubscription<PatientProfile>? _subscription;

  void _subscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = AsyncValue.error('No active user session', StackTrace.current);
      return;
    }

    _subscription = _ref
        .read(watchPatientProfileProvider)
        .call(user.uid)
        .listen(
          (profile) => state = AsyncValue.data(profile),
          onError: (Object err, StackTrace stack) =>
              state = AsyncValue.error(err, stack),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ref.read(updatePatientProfileProvider).call(user.uid, updates);
  }

  Future<void> updateAvatar(String avatarDataUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ref.read(updatePatientAvatarProvider).call(user.uid, avatarDataUrl);
  }
}

final patientProfileProvider =
    StateNotifierProvider<PatientProfileController, AsyncValue<PatientProfile>>((
      ref,
    ) {
      return PatientProfileController(ref);
    });