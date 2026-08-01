// lib/features/profile/presentation/providers/care_circle_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/care_member.dart';
import 'profile_providers.dart';

/// Same public name as the old `careCircleProvider`
/// (`providers/care_circle_provider.dart`), now backed by a use case
/// instead of returning a hardcoded list inline. Still mock data under
/// the hood for now — see `CareCircleRepositoryImpl`.
final careCircleProvider = FutureProvider<List<CareMember>>((ref) {
  return ref.watch(getCareCircleProvider).call();
});