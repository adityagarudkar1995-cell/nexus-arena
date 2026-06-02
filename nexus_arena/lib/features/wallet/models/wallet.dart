class Wallet {
  final String id;
  final String userId;
  final int balancePaise;
  final int totalDepositedPaise;
  final int totalWithdrawnPaise;
  final int totalWonPaise;
  final int totalTdsDeductedPaise;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balancePaise,
    required this.totalDepositedPaise,
    required this.totalWithdrawnPaise,
    required this.totalWonPaise,
    required this.totalTdsDeductedPaise,
  });

  int get balanceRs => balancePaise ~/ 100;
  int get totalDepositedRs => totalDepositedPaise ~/ 100;
  int get totalWithdrawnRs => totalWithdrawnPaise ~/ 100;
  int get totalWonRs => totalWonPaise ~/ 100;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balancePaise: int.tryParse(json['balance']?.toString() ?? '') ?? 0,
      totalDepositedPaise: int.tryParse(json['total_deposited']?.toString() ?? '') ?? 0,
      totalWithdrawnPaise: int.tryParse(json['total_withdrawn']?.toString() ?? '') ?? 0,
      totalWonPaise: int.tryParse(json['total_won']?.toString() ?? '') ?? 0,
      totalTdsDeductedPaise: int.tryParse(json['total_tds_deducted']?.toString() ?? '') ?? 0,
    );
  }
}
