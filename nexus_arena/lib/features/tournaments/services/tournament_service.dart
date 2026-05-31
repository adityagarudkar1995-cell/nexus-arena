import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../models/tournament.dart';
import '../models/tournament_registration.dart';

class TournamentService {
  static Future<List<Tournament>> fetchTournaments() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/tournaments?status=neq.draft&order=scheduled_at.asc',
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(Tournament.fromJson)
        .toList();
  }

  static Future<Tournament> fetchTournamentById(String id) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/tournaments?id=eq.$id&limit=1',
    );
    if (data.isEmpty) throw ApiException('tournament_not_found', 404);
    return Tournament.fromJson(data.first as Map<String, dynamic>);
  }

  static Future<TournamentRegistration?> fetchMyRegistration(
      String tournamentId) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/tournament_registrations?tournament_id=eq.$tournamentId&limit=1',
    );
    if (data.isEmpty) return null;
    return TournamentRegistration.fromJson(data.first as Map<String, dynamic>);
  }

  static Future<List<TournamentRegistration>> fetchMyRegistrations() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/tournament_registrations?order=registered_at.desc',
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(TournamentRegistration.fromJson)
        .toList();
  }
}
