import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tournament.dart';
import '../models/tournament_registration.dart';
import '../services/tournament_service.dart';

class TournamentsNotifier extends AsyncNotifier<List<Tournament>> {
  @override
  Future<List<Tournament>> build() => TournamentService.fetchTournaments();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(TournamentService.fetchTournaments);
  }
}

final tournamentsProvider =
    AsyncNotifierProvider<TournamentsNotifier, List<Tournament>>(
  TournamentsNotifier.new,
);

class MyRegistrationsNotifier
    extends AsyncNotifier<List<TournamentRegistration>> {
  @override
  Future<List<TournamentRegistration>> build() =>
      TournamentService.fetchMyRegistrations();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(TournamentService.fetchMyRegistrations);
  }
}

final myRegistrationsProvider =
    AsyncNotifierProvider<MyRegistrationsNotifier, List<TournamentRegistration>>(
  MyRegistrationsNotifier.new,
);

final joinedTournamentIdsProvider = Provider<Set<String>>((ref) {
  return ref
          .watch(myRegistrationsProvider)
          .valueOrNull
          ?.where((r) => r.isActive)
          .map((r) => r.tournamentId)
          .toSet() ??
      {};
});
