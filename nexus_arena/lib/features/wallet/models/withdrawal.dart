class Withdrawal {
  final String id;
  final String userId;
  final int amountPaise;
  final String upiId;
  final String status; // pending | processing | completed | failed | rejected
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const Withdrawal({
    required this.id,
    required this.userId,
    required this.amountPaise,
    required this.upiId,
    required this.status,
    this.rejectionReason,
    required this.requestedAt,
    this.processedAt,
  });

  int get amountRs => amountPaise ~/ 100;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';

  factory Withdrawal.fromJson(Map<String, dynamic> json) {
    return Withdrawal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amountPaise: int.tryParse(json['amount']?.toString() ?? '') ?? 0,
      upiId: json['upi_id'] as String,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String).toLocal(),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String).toLocal()
          : null,
    );
  }
}
