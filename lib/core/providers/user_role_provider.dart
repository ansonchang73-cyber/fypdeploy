// lib/core/providers/user_role_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_role.dart';

/// Streams the signed-in user's role straight from their `users/{uid}`
/// document. This is deliberately NOT the same thing as
/// `features/auth`'s `authProvider.userRole` — that field only ever
/// reflects whatever was passed to `login()`/`register()` in the moment
/// (and `login_screen.dart` always passes `UserRole.none`), so it can't
/// be trusted to answer "what is this signed-in user's role" after the
/// fact. This reads the actual stored value instead, which is what
/// role-based routing needs.
final currentUserRoleProvider = StreamProvider<UserRole>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(UserRole.none);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        final raw = snapshot.data()?['role'] as String?;
        switch (raw) {
          case 'patient':
            return UserRole.patient;
          case 'caregiver':
            return UserRole.caregiver;
          default:
            return UserRole.none;
        }
      });
});
