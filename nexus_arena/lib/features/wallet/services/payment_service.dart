import '../../../core/api_client.dart';
import '../../auth/services/auth_service.dart';

/// Result of creating a Razorpay order on the backend.
class RazorpayOrder {
  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;

  const RazorpayOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> json) {
    return RazorpayOrder(
      orderId: json['order_id'] as String,
      amountPaise: int.parse(json['amount'].toString()),
      currency: json['currency'] as String? ?? 'INR',
      keyId: json['key_id'] as String? ?? '',
    );
  }
}

class PaymentService {
  /// Creates a server-side Razorpay order for [amountRs] (min ₹50, max ₹10,000).
  static Future<RazorpayOrder> createOrder(int amountRs) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final res = await client.post(
      '/create-razorpay-order',
      {'amount_rs': amountRs},
      isFunction: true,
    );
    return RazorpayOrder.fromJson(res);
  }

  /// Verifies the payment signature server-side and credits the wallet.
  /// Returns true on success (including idempotent already-processed).
  static Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final res = await client.post(
      '/verify-razorpay-payment',
      {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
      isFunction: true,
    );
    return res['success'] == true;
  }
}
