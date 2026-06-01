class AppConstants {
  static const insforgeBaseUrl    = 'https://xymp52ea.ap-southeast.insforge.app';
  static const functionsBaseUrl   = 'https://xymp52ea.functions.insforge.app';
  static const insforgeAnonKey    = String.fromEnvironment('INSFORGE_ANON_KEY');

  // Razorpay publishable key_id (safe on client). Pass via --dart-define.
  static const razorpayKeyId      = String.fromEnvironment('RAZORPAY_KEY_ID');

  // Top-up limits (Rs)
  static const minTopUpRs = 50;
  static const maxTopUpRs = 10000;

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
