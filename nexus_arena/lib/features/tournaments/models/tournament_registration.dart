class TournamentRegistration {
  final String id;
  final String tournamentId;
  final String userId;
  final String? teamName;
  final List<String> teamMembers;
  final String status;
  final DateTime registeredAt;

  const TournamentRegistration({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.teamName,
    required this.teamMembers,
    required this.status,
    required this.registeredAt,
  });

  bool get isActive =>
      !['refunded', 'disqualified'].contains(status);

  factory TournamentRegistration.fromJson(Map<String, dynamic> json) {
    return TournamentRegistration(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      userId: json['user_id'] as String,
      teamName: json['team_name'] as String?,
      teamMembers: (json['team_members'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: json['status'] as String,
      registeredAt: DateTime.parse(json['registered_at'] as String).toLocal(),
    );
  }
}
