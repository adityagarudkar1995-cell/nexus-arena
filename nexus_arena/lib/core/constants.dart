class AppConstants {
  static const insforgeBaseUrl    = 'https://xymp52ea.ap-southeast.insforge.app';
  static const functionsBaseUrl   = 'https://xymp52ea.functions.insforge.app';
  static const insforgeAnonKey    = String.fromEnvironment('INSFORGE_ANON_KEY');

  // Wallet
  static const maxWithdrawalPerDayRs = 10000;
  static const tdsPercent            = 30;

  // Entry fees (Rs)
  static const entryFeeSoloRs  = 50;
  static const entryFeeDuoRs   = 100;
  static const entryFeeSquadRs = 250;

  // Room ID visibility window
  static const roomIdVisibleMinutesBefore = 15;
}
