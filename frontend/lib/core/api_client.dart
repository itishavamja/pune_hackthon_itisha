import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'config.dart';

/// A failed API call, already turned into something safe to show a merchant.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.status,
    this.code = 'error',
    this.isNetwork = false,
  });

  final String message;
  final int? status;
  final String code;

  /// True when the server could not be reached at all (offline / wrong URL / server stopped).
  final bool isNetwork;

  bool get isConflict => status == 409;
  bool get isNotFound => status == 404;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  // The backend's first forecast call after a restart loads heavy statistics libraries (~15s),
  // so reads get a generous limit instead of showing a false "server not reachable".
  static const _normal = Duration(seconds: 45);
  // POST /analyze may wait for the AI service (30s timeout + 1 retry on the server).
  static const _slow = Duration(seconds: 95);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
    Duration timeout = _normal,
  }) async {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    var uri = Uri.parse('$base$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    final allHeaders = <String, String>{
      'Accept': 'application/json',
      'X-Merchant-Id': '$kMerchantId',
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    };

    late http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(allHeaders);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _http.send(req).timeout(timeout);
      res = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        message: 'Dukaan360 is taking too long to answer. Please wait a moment and try again.',
        isNetwork: true,
        code: 'timeout',
      );
    } catch (_) {
      throw ApiException(
        message: "The app can't reach Dukaan360. Please check your internet connection.",
        isNetwork: true,
        code: 'network',
      );
    }

    // Always decode as UTF-8 so Hindi / Marathi text is never garbled.
    final text = utf8.decode(res.bodyBytes);
    dynamic json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      json = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    // Backend error shape: {"error": "...", "message": "...", "detail": ...}
    String message = 'Something went wrong (${res.statusCode}).';
    String code = 'error';
    if (json is Map) {
      if (json['message'] is String) message = json['message'] as String;
      if (json['error'] is String) code = json['error'] as String;
      if (json['message'] == null && json['detail'] is String) message = json['detail'] as String;
    }
    throw ApiException(message: message, status: res.statusCode, code: code);
  }

  // ----------------------------------------------------------- system
  Future<bool> health() async {
    final j = await _send('GET', '/health', timeout: const Duration(seconds: 6));
    return j is Map && j['status'] == 'ok';
  }

  // ----------------------------------------------------------- dashboard
  Future<Summary> summary() async => Summary.fromJson(await _send('GET', '/summary'));

  Future<Forecast> forecast({int historyDays = 30}) async =>
      Forecast.fromJson(await _send('GET', '/forecast', query: {'history_days': '$historyDays'}));

  Future<ChurnPage> churn({int limit = 20, int offset = 0, String? riskLevel}) async =>
      ChurnPage.fromJson(await _send('GET', '/churn', query: {
        'limit': '$limit',
        'offset': '$offset',
        if (riskLevel != null) 'risk_level': riskLevel,
      }));

  Future<AlertsPage> alerts({int limit = 100, int offset = 0, String? severity}) async =>
      AlertsPage.fromJson(await _send('GET', '/alerts', query: {
        'limit': '$limit',
        'offset': '$offset',
        if (severity != null) 'severity': severity,
      }));

  // ----------------------------------------------------------- analysis
  Future<AnalysisResult> analyze({required String language, required String idempotencyKey}) async {
    final j = await _send(
      'POST',
      '/analyze',
      body: {'language': language},
      headers: {'Idempotency-Key': idempotencyKey},
      timeout: _slow,
    );
    return AnalysisResult.fromJson(j as Map<String, dynamic>);
  }

  // ----------------------------------------------------------- campaigns
  Future<CampaignsPage> campaigns({int limit = 100, int offset = 0, String? status}) async =>
      CampaignsPage.fromJson(await _send('GET', '/campaigns', query: {
        'limit': '$limit',
        'offset': '$offset',
        if (status != null) 'status': status,
      }));

  Future<Campaign> campaign(int id) async => Campaign.fromJson(await _send('GET', '/campaigns/$id'));

  Future<Campaign> editCampaign(int id, {String? title, String? message}) async => Campaign.fromJson(
        await _send('PUT', '/campaigns/$id', body: {
          if (title != null) 'title': title,
          if (message != null) 'message': message,
        }),
      );

  Future<ActionResult> approve(int id) async =>
      ActionResult.fromJson(await _send('POST', '/campaigns/$id/approve', timeout: _slow));

  Future<ActionResult> reject(int id) async =>
      ActionResult.fromJson(await _send('POST', '/campaigns/$id/reject'));

  // ----------------------------------------------------------- ask
  Future<AskResult> ask(String question, String language) async => AskResult.fromJson(
        await _send('POST', '/ask', body: {'question': question, 'language': language}, timeout: _slow),
      );

  void close() => _http.close();
}
