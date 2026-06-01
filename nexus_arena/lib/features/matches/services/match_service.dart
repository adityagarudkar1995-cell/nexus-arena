import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../models/match.dart';
import '../models/match_lobby.dart';
import '../models/match_result.dart';

class MatchService {
  static Future<MatchLobby> fetchMatchLobby(String matchId) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/match_lobby?id=eq.$matchId&limit=1',
    );
    if (data.isEmpty) throw ApiException('match_not_found', 404);
    return MatchLobby.fromJson(data.first as Map<String, dynamic>);
  }

  static Future<List<MatchResult>> fetchMatchResults(String matchId) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/match_results?match_id=eq.$matchId&order=rank.asc',
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(MatchResult.fromJson)
        .toList();
  }

  static Future<Match?> fetchMatchForTournament(String tournamentId) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/matches?tournament_id=eq.$tournamentId&order=scheduled_at.asc&limit=1',
    );
    if (data.isEmpty) return null;
    return Match.fromJson(data.first as Map<String, dynamic>);
  }

  /// Returns all match results for the authenticated user (RLS auto-filters).
  static Future<List<MatchResult>> fetchMyResults() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/match_results?order=created_at.desc',
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(MatchResult.fromJson)
        .toList();
  }

  static Future<Map<String, dynamic>> joinTournament(
    String tournamentId, {
    String? teamName,
    List<String>? teamMembers,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final body = <String, dynamic>{'tournament_id': tournamentId};
    if (teamName != null) body['team_name'] = teamName;
    if (teamMembers != null && teamMembers.isNotEmpty) {
      body['team_members'] = teamMembers;
    }
    return client.post('/join-tournament', body, isFunction: true);
  }
}
