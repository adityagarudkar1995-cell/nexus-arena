import 'package:go_router/go_router.dart';
import '../features/auth/screens/phone_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/home/screens/home_screen.dart';

final router = GoRouter(
  initialLocation: '/phone',
  redirect: (context, state) async {
    final authed  = await AuthService.isAuthenticated();
    final onAuth  = state.matchedLocation.startsWith('/phone') ||
                    state.matchedLocation.startsWith('/otp');
    if (authed && onAuth) return '/home';
    if (!authed && !onAuth) return '/phone';
    return null;
  },
  routes: [
    GoRoute(
      path: '/phone',
      builder: (ctx, s) => const PhoneScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (_, state) => OtpScreen(phone: state.extra as String),
    ),
    GoRoute(
      path: '/home',
      builder: (ctx, s) => const HomeScreen(),
    ),
  ],
);
