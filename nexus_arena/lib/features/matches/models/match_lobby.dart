class MatchLobby {
  final String id;
  final String tournamentId;
  final String status;
  final DateTime scheduledAt;
  final DateTime? roomIdVisibleAt;
  final String? roomId;
  final String? roomPassword;

  const MatchLobby({
    required this.id,
    required this.tournamentId,
    required this.status,
    required this.scheduledAt,
    this.roomIdVisibleAt,
    this.roomId,
    this.roomPassword,
  });

  bool get isRoomVisible {
    if (roomId == null || roomId!.isEmpty) return false;
    if (roomIdVisibleAt == null) return false;
    return DateTime.now().isAfter(roomIdVisibleAt!);
  }

  bool get isMatchStarted =>
      ['live', 'completed', 'cancelled'].contains(status);

  Duration get timeUntilVisible {
    if (roomIdVisibleAt == null) return Duration.zero;
    final diff = roomIdVisibleAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration get timeUntilMatch {
    final diff = scheduledAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory MatchLobby.fromJson(Map<String, dynamic> json) {
    return MatchLobby(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      status: json['status'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      roomIdVisibleAt: json['room_id_visible_at'] != null
          ? DateTime.parse(json['room_id_visible_at'] as String).toLocal()
          : null,
      roomId: json['room_id'] as String?,
      roomPassword: json['room_password'] as String?,
    );
  }
}
