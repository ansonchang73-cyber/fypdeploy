// lib/core/widgets/role_based_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/caregiver_dashboard/presentation/screens/caregiver_dashboard_shell.dart';
import '../providers/user_role_provider.dart';
import 'dashboard_screen.dart';

/// Sits at the `/home` route and picks which dashboard shell to show
/// based on the signed-in user's actual stored role. Patients (and the
/// 'none'/unset fallback, so nothing breaks for any account that
/// predates roles) get [MainDashboardScreen]; caregivers get
/// [CaregiverDashboardShell].
class RoleBasedDashboard extends ConsumerWidget {
  const RoleBasedDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(currentUserRoleProvider);

    // Both shells hold local state (which bottom-nav tab is selected).
    // Keying by the signed-in user's UID guarantees Flutter tears down
    // and rebuilds that state fresh on every distinct login, rather than
    // ever risking a stale tab selection (e.g. "Profile") carrying over
    // from a previous session.
    final String shellKeyValue = FirebaseAuth.instance.currentUser?.uid ?? 'signed-out';

    return roleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (role) {
        if (role == UserRole.caregiver) {
          return CaregiverDashboardShell(key: ValueKey('caregiver-$shellKeyValue'));
        }
        return MainDashboardScreen(key: ValueKey('patient-$shellKeyValue'));
      },
    );
  }
}
