class WalletTransaction {
  final String id;
  final String userId;
  final String type; // deposit | withdrawal | entry_fee | prize | tds | refund
  final int amountPaise; // positive = credit, negative = debit
  final int balanceAfterPaise;
  final String? referenceType;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amountPaise,
    required this.balanceAfterPaise,
    this.referenceType,
    this.description,
    required this.createdAt,
  });

  int get amountRs => amountPaise.abs() ~/ 100;
  bool get isCredit => amountPaise > 0;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      amountPaise: int.tryParse(json['amount']?.toString() ?? '') ?? 0,
      balanceAfterPaise: int.tryParse(json['balance_after']?.toString() ?? '') ?? 0,
      referenceType: json['reference_type'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
