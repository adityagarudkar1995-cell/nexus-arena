import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../auth/services/auth_service.dart';

class KycService {
  /// Uploads [file] to the private `kyc-documents` bucket under the user's own
  /// folder (`{userId}/...`) and returns the storage object key.
  static Future<String> uploadDocument({
    required String userId,
    required String docType, // aadhaar_front | aadhaar_back | pan_card | selfie
    required File file,
  }) async {
    final token = await AuthService.getToken();
    final ext = file.path.split('.').last.toLowerCase();
    final key =
        '$userId/${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final uri = Uri.parse(
      '${AppConstants.insforgeBaseUrl}/api/storage/buckets/kyc-documents/objects/$key',
    );
    final req = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['apikey'] = AppConstants.insforgeAnonKey
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode >= 400) {
      throw ApiException('upload_failed', resp.statusCode);
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['key'] as String? ?? key;
  }

  /// Records the submission and flips kyc_status to 'submitted' (server-side).
  static Future<Map<String, dynamic>> submitKyc({
    required String aadhaarFront,
    required String aadhaarBack,
    required String panCard,
    required String selfie,
  }) async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    return client.post(
      '/submit-kyc',
      {
        'aadhaar_front': aadhaarFront,
        'aadhaar_back': aadhaarBack,
        'pan_card': panCard,
        'selfie': selfie,
      },
      isFunction: true,
    );
  }

  /// Latest submission's rejection reason (for the rejected state). Null if none.
  static Future<String?> fetchLatestRejectionReason() async {
    final token = await AuthService.getToken();
    final client = ApiClient(accessToken: token);
    final data = await client.getList(
      '/rest/v1/kyc_submissions?order=submitted_at.desc&limit=1&select=rejection_reason',
    );
    if (data.isEmpty) return null;
    return (data.first as Map<String, dynamic>)['rejection_reason'] as String?;
  }
}
