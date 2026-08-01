// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/registration_details.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> register(RegistrationDetails details) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: details.email,
      password: details.password,
    );

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'fullName': details.fullName,
      'email': details.email,
      'role': details.role.name,
      'createdAt': FieldValue.serverTimestamp(),
      'age': int.tryParse(details.age) ?? 0,
      'gender': details.gender.isEmpty ? 'Not Specified' : details.gender,
      'bloodType': details.bloodType.isEmpty ? 'Unknown' : details.bloodType,
      'avatarUrl': 'https://i.pravatar.cc/150?img=11',
    });
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }
}
