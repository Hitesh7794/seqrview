import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // for convenience/resume
  static const _mobileKey = 'mobile';
  static const _kycSessionKey = 'kyc_session_uid';

  // ✅ NEW: persistent cooldown (Aadhaar OTP request)
  static const _aadhaarCooldownUntilKey = 'aadhaar_otp_cooldown_until';
  static const _themeKey = 'app_theme_is_dark';
  static const _aadhaarDetailsKey = 'aadhaar_details_json';

  Future<void> saveTheme(bool isDark) => _storage.write(key: _themeKey, value: isDark.toString());
  
  Future<bool> getIsDarkTheme() async {
    final val = await _storage.read(key: _themeKey);
    return val == 'true'; // Default false (Light) if null
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> getAccess() => _storage.read(key: _accessKey);
  Future<String?> getRefresh() => _storage.read(key: _refreshKey);

  Future<void> saveMobile(String mobile) => _storage.write(key: _mobileKey, value: mobile);
  Future<String?> getMobile() => _storage.read(key: _mobileKey);

  Future<void> saveKycSessionUid(String uid) => _storage.write(key: _kycSessionKey, value: uid);
  Future<String?> getKycSessionUid() => _storage.read(key: _kycSessionKey);
  Future<void> clearKycSessionUid() => _storage.delete(key: _kycSessionKey);

  // ✅ NEW: cooldown methods
  Future<void> saveAadhaarCooldownUntil(DateTime dt) =>
      _storage.write(key: _aadhaarCooldownUntilKey, value: dt.toIso8601String());

  Future<DateTime?> getAadhaarCooldownUntil() async {
    final v = await _storage.read(key: _aadhaarCooldownUntilKey);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  Future<void> clearAadhaarCooldownUntil() => _storage.delete(key: _aadhaarCooldownUntilKey);

  Future<void> saveAadhaarDetails(String json) => _storage.write(key: _aadhaarDetailsKey, value: json);
  Future<String?> getAadhaarDetails() => _storage.read(key: _aadhaarDetailsKey);
  Future<void> clearAadhaarDetails() => _storage.delete(key: _aadhaarDetailsKey);

  Future<void> clearAll() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _mobileKey);
    await _storage.delete(key: _kycSessionKey);
    await _storage.delete(key: _aadhaarCooldownUntilKey);
    await _storage.delete(key: _aadhaarDetailsKey);
  }
}
