// lib/features/auth/presentation/providers/auth_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(FirebaseAuth.instance, FirebaseFirestore.instance);
});

final loginProvider = Provider<Login>((ref) {
  return Login(ref.watch(authRepositoryProvider));
});

final registerProvider = Provider<Register>((ref) {
  return Register(ref.watch(authRepositoryProvider));
});

final logoutProvider = Provider<Logout>((ref) {
  return Logout(ref.watch(authRepositoryProvider));
});
