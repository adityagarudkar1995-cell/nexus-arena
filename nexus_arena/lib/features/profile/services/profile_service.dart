import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../models/profile.dart';

/// Lightweight stats for the profile screen: counts from RLS-filtered queries.
typedef PlayerStats = ({int matchesPlayed, int wins});

class ProfileService {
  static Future<Profile> fetchProfile() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList('/rest/v1/profiles?limit=1');
    if (data.isEmpty) throw ApiException('profile_not_found', 404);
    return Profile.fromJson(data.first as Map<String, dynamic>);
  }

  static Future<PlayerStats> fetchPlayerStats() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final results = await Future.wait([
      // RLS auto-filters both queries to the authenticated user.
      client.getList('/rest/v1/tournament_registrations?select=id'),
      client.getList('/rest/v1/match_results?rank=eq.1&select=id'),
    ]);
    return (
      matchesPlayed: results[0].length,
      wins: results[1].length,
    );
  }

  static Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? gameUid,
    String? upiId,
    String? avatarUrl,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (gameUid != null) body['game_uid'] = gameUid;
    if (upiId != null) body['upi_id'] = upiId;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (body.isEmpty) return;
    await client.patch('/rest/v1/profiles?id=eq.$userId', body);
  }
}
