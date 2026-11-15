import 'package:flutter/foundation.dart';

/// The demo merchant. The backend uses the `X-Merchant-Id` header as demo auth.
const int kMerchantId = 1;

/// Where the FastAPI backend lives.
///
/// * Android emulator  -> http://10.0.2.2:8000   (10.0.2.2 is the host PC)
/// * Chrome / desktop  -> http://127.0.0.1:8000
/// * Real phone        -> http://YOUR-PC-LAN-IP:8000  (set it in the app: Settings)
///
/// Override at build time:  flutter run --dart-define=API_URL=http://192.168.1.5:8000
String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

const String kPrefApiUrl = 'api_url';
const String kPrefLastAnalysis = 'last_analysis';
const String kPrefLanguage = 'language';
const String kPrefOnboarded = 'onboarded';
