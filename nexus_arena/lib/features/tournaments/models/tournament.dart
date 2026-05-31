import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class Tournament {
  final String id;
  final String title;
  final String game;
  final String mode;           // 'solo' | 'duo' | 'squad'
  final String tournamentType; // 'daily' | 'weekly'
  final int tier;              // 1 or 2
  final int entryFee;          // Rs — stored as Rs in DB, not paise
  final int prizePoolPaise;
  final int prize1stPaise;
  final int prize2ndPaise;
  final int prize3rdPaise;
  final int maxTeams;
  final int registeredCount;
  final int minPlayers;
  final String status;
  final DateTime scheduledAt;
  final String? rules;
  final String? bannerUrl;

  const Tournament({
    required this.id,
    required this.title,
    required this.game,
    required this.mode,
    required this.tournamentType,
    required this.tier,
    required this.entryFee,
    required this.prizePoolPaise,
    required this.prize1stPaise,
    required this.prize2ndPaise,
    required this.prize3rdPaise,
    required this.maxTeams,
    required this.registeredCount,
    required this.minPlayers,
    required this.status,
    required this.scheduledAt,
    this.rules,
    this.bannerUrl,
  });

  int get prizePoolRs => prizePoolPaise ~/ 100;
  int get prize1stRs => prize1stPaise ~/ 100;
  int get prize2ndRs => prize2ndPaise ~/ 100;
  int get prize3rdRs => prize3rdPaise ~/ 100;
  String get modeDisplay => mode.toUpperCase();
  bool get isDaily => tournamentType == 'daily';
  bool get isWeekly => tournamentType == 'weekly';
  bool get isFull => registeredCount >= maxTeams;

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      title: json['title'] as String,
      game: json['game'] as String,
      mode: json['mode'] as String,
      tournamentType: json['tournament_type'] as String? ?? 'daily',
      tier: (json['tier'] as int?) ?? 1,
      entryFee: (json['entry_fee'] as int?) ?? 0,
      prizePoolPaise: int.parse(json['prize_pool']?.toString() ?? '0'),
      prize1stPaise: int.parse(json['prize_1st']?.toString() ?? '0'),
      prize2ndPaise: int.parse(json['prize_2nd']?.toString() ?? '0'),
      prize3rdPaise: int.parse(json['prize_3rd']?.toString() ?? '0'),
      maxTeams: (json['max_teams'] as int?) ?? 0,
      registeredCount: (json['registered_count'] as int?) ?? 0,
      minPlayers: (json['min_players'] as int?) ?? 30,
      status: json['status'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      rules: json['rules'] as String?,
      bannerUrl: json['banner_url'] as String?,
    );
  }

  static (String, Color) statusDisplay(String status) {
    return switch (status) {
      'registration_open'   => ('OPEN',      AppColors.accent),
      'ongoing'             => ('LIVE',      Colors.orange),
      'registration_closed' => ('CLOSED',    AppColors.muted),
      'completed'           => ('ENDED',     AppColors.muted),
      'cancelled'           => ('CANCELLED', AppColors.danger),
      _                     => ('UNKNOWN',   AppColors.muted),
    };
  }
}
