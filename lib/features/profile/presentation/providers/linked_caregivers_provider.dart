// lib/features/profile/presentation/providers/linked_caregivers_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/linked_caregiver_summary.dart';
import 'profile_providers.dart';

/// Every caregiver linked to the signed-in patient — this is what
/// `settings_screen.dart`'s Care Circle section actually displays now,
/// replacing the hardcoded "No active caregiver linked to account." text
/// that was there regardless of whether anyone had actually linked.
final linkedCaregiversProvider = FutureProvider<List<LinkedCaregiverSummary>>((
  ref,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Future.value(const []);
  return ref.watch(getLinkedCaregiversProvider).call(user.uid);
});
