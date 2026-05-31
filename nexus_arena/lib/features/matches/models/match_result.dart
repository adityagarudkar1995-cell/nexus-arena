class MatchResult {
  final String id;
  final String matchId;
  final String registrationId;
  final int rank;
  final int kills;
  final int points;
  final int prizeAmountPaise;
  final int tdsPaise;
  final int netPrizePaise;
  final DateTime? paidAt;

  const MatchResult({
    required this.id,
    required this.matchId,
    required this.registrationId,
    required this.rank,
    required this.kills,
    required this.points,
    required this.prizeAmountPaise,
    required this.tdsPaise,
    required this.netPrizePaise,
    this.paidAt,
  });

  int get prizeRs => prizeAmountPaise ~/ 100;
  int get tdsRs => tdsPaise ~/ 100;
  int get netPrizeRs => netPrizePaise ~/ 100;

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      registrationId: json['registration_id'] as String,
      rank: json['rank'] as int,
      kills: (json['kills'] as int?) ?? 0,
      points: (json['points'] as int?) ?? 0,
      prizeAmountPaise: int.parse(json['prize_amount']?.toString() ?? '0'),
      tdsPaise: int.parse(json['tds_amount']?.toString() ?? '0'),
      netPrizePaise: int.parse(json['net_prize']?.toString() ?? '0'),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String).toLocal()
          : null,
    );
  }
}
