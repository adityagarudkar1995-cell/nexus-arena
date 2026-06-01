import 'package:go_router/go_router.dart';
import '../features/auth/screens/phone_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/home/screens/home_screen.dart';
import '../features/tournaments/screens/tournament_detail_screen.dart';
import '../features/matches/screens/match_lobby_screen.dart';
import '../features/wallet/screens/wallet_screen.dart';
import '../features/wallet/screens/add_money_screen.dart';
import '../features/wallet/screens/withdraw_screen.dart';
import '../features/results/screens/results_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/kyc/screens/kyc_screen.dart';
import '../features/settings/screens/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/phone',
  redirect: (context, state) async {
    final authed = await AuthService.isAuthenticated();
    final onAuth = state.matchedLocation.startsWith('/phone') ||
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
    GoRoute(
      path: '/tournament/:id',
      builder: (ctx, state) => TournamentDetailScreen(
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/match-lobby/:id',
      builder: (ctx, state) => MatchLobbyScreen(
        id: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/wallet',
      builder: (ctx, s) => const WalletScreen(),
    ),
    GoRoute(
      path: '/add-money',
      builder: (ctx, s) => const AddMoneyScreen(),
    ),
    GoRoute(
      path: '/withdraw',
      builder: (ctx, s) => const WithdrawScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (ctx, s) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (ctx, s) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (ctx, s) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/kyc',
      builder: (ctx, s) => const KycScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (ctx, s) => const SettingsScreen(),
    ),
  ],
);
