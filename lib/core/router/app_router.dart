import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_app/core/widgets/role_based_dashboard.dart';
import 'package:go_router/go_router.dart';

// Import all the screens we built!
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      // 1. The Login Page stays outside the shell
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // 2. Add this route for registration
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => RegisterScreen(),
      ),
      // 2. Everything else goes into the "Shell" (The Frame)
      GoRoute(
        path: '/home', // or your main home path
        builder: (context, state) => const RoleBasedDashboard(),
      ),
    ],
  );
});