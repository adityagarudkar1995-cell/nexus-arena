import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../models/profile.dart';

class ProfileService {
  static Future<Profile> fetchProfile() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList('/rest/v1/profiles?limit=1');
    if (data.isEmpty) throw ApiException('profile_not_found', 404);
    return Profile.fromJson(data.first as Map<String, dynamic>);
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
