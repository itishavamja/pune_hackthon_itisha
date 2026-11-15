import 'dart:async';
import 'dart:convert';

import 'package:dukaan360_app/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  test('sends merchant header, query params and idempotency key', () async {
    late http.Request seen;
    final api = ApiClient('http://x:8000/', client: MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode(analysisJson()), 200, headers: {'content-type': 'application/json'});
    }));
    await api.analyze(language: 'Hindi', idempotencyKey: 'k-1');
    expect(seen.url.toString(), 'http://x:8000/analyze'); // trailing slash handled
    expect(seen.method, 'POST');
    expect(seen.headers['X-Merchant-Id'], '1');
    expect(seen.headers['Idempotency-Key'], 'k-1');
    expect(jsonDecode(seen.body), {'language': 'Hindi'});

    final api2 = ApiClient('http://x:8000', client: MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode(churnJson()), 200);
    }));
    await api2.churn(limit: 5, offset: 10, riskLevel: 'HIGH');
    expect(seen.url.queryParameters, {'limit': '5', 'offset': '10', 'risk_level': 'HIGH'});
  });

  test('Hindi text survives (UTF-8 decoding)', () async {
    final api = ApiClient('http://x', client: MockClient((req) async {
      // Deliberately NO charset header: the client must still decode as UTF-8.
      return http.Response.bytes(utf8.encode(jsonEncode(campaignJson())), 200);
    }));
    final c = await api.campaign(1);
    expect(c.title, 'वापसी का खास ऑफर');
  });

  test('backend error shape becomes ApiException with its message', () async {
    final api = ApiClient('http://x', client: MockClient((req) async {
      return http.Response(
        jsonEncode({'error': 'conflict', 'message': 'Rejected campaigns cannot be approved or sent', 'detail': null}),
        409,
      );
    }));
    try {
      await api.approve(1);
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(e.isConflict, true);
      expect(e.code, 'conflict');
      expect(e.message, 'Rejected campaigns cannot be approved or sent');
      expect(e.isNetwork, false);
    }
  });

  test('unknown error body still gives a friendly message', () async {
    final api = ApiClient('http://x', client: MockClient((req) async => http.Response('<html>boom</html>', 500)));
    await expectLater(api.summary(), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('500'))));
  });

  test('unreachable server is reported as a network error', () async {
    final api = ApiClient('http://x', client: MockClient((req) async => throw http.ClientException('socket')));
    await expectLater(api.summary(), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });

  test('timeouts are reported as network errors', () async {
    final api = ApiClient('http://x', client: MockClient((req) async => throw TimeoutException('slow')));
    await expectLater(api.summary(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')));
  });
}
