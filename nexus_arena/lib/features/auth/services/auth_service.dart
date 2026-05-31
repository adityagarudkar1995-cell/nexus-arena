import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api_client.dart';

const _tokenKey = 'access_token';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _client  = ApiClient();

  static Future<void> sendOtp(String phone) async {
    await _client.post('/send-otp', {'phone': phone}, isFunction: true);
  }

  static Future<String> verifyOtp(String phone, String code) async {
    final data = await _client.post('/verify-otp', {'phone': phone, 'code': code}, isFunction: true);
    final token = data['accessToken'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> signOut() => _storage.delete(key: _tokenKey);

  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
