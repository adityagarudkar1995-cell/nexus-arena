class Match {
  final String id;
  final String tournamentId;
  final String status;
  final DateTime scheduledAt;
  final DateTime? roomIdVisibleAt;

  const Match({
    required this.id,
    required this.tournamentId,
    required this.status,
    required this.scheduledAt,
    this.roomIdVisibleAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      status: json['status'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      roomIdVisibleAt: json['room_id_visible_at'] != null
          ? DateTime.parse(json['room_id_visible_at'] as String).toLocal()
          : null,
    );
  }
}
