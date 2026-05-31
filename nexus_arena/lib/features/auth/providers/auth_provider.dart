import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../../profile/models/profile.dart';
import '../../profile/services/profile_service.dart';

class AuthNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final authed = await AuthService.isAuthenticated();
    if (!authed) return null;
    try {
      return await ProfileService.fetchProfile();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authed = await AuthService.isAuthenticated();
      if (!authed) return null;
      return ProfileService.fetchProfile();
    });
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Profile?>(
  AuthNotifier.new,
);
