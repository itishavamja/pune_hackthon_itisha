import 'package:dukaan360_app/core/format.dart';
import 'package:dukaan360_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('formatting', () {
    test('rupees use Indian digit grouping', () {
      expect(money(299861), '₹2,99,861');
      expect(money(1150730), '₹11,50,730');
      expect(money(60029), '₹60,029');
      expect(money(0), '₹0');
    });

    test('short money for chart axes', () {
      expect(moneyShort(500), '₹500');
      expect(moneyShort(1500), '₹1.5k');
      expect(moneyShort(12000), '₹12k');
      expect(moneyShort(150000), '₹1.5L');
    });

    test('percent helpers', () {
      expect(signedPct(-19.97), '-20.0%');
      expect(signedPct(4.5), '+4.5%');
      expect(pct(20), '20%');
    });

    test('initials and dates', () {
      expect(initials('Manisha Wagh'), 'MW');
      expect(initials('  '), '?');
      expect(dayMonthFromIso('2026-10-26'), '26 Oct');
      expect(dayMonthFromIso(null), '—');
    });
  });

  group('models', () {
    test('summary parses numbers (ints or doubles)', () {
      final s = Summary.fromJson({...summaryJson(), 'today_revenue': 100}); // int in JSON
      expect(s.todayRevenue, 100.0);
      expect(s.growthPct, -19.97);
      expect(s.atRiskCustomers, 29);
    });

    test('naive backend timestamps are treated as UTC', () {
      final d = parseUtc('2026-11-14T18:04:46.309534')!;
      expect(d.toUtc().hour, 18);
      expect(d.toUtc().isUtc, true);
      expect(parseUtc(null), isNull);
    });

    test('forecast keeps history and forecast apart', () {
      final f = Forecast.fromJson(forecastJson());
      expect(f.history.length, 30);
      expect(f.forecast.length, 7);
      expect(f.isDeclining, true);
      expect(f.projectedChangePct, -30.31);
    });

    test('churn page', () {
      final p = ChurnPage.fromJson(churnJson());
      expect(p.customers.first.isHigh, true);
      expect(p.segments.map((s) => s.name), contains('At Risk'));
      expect(p.summary.churnRiskPct, 19.33);
    });

    test('campaign keeps Hindi text intact and handles missing history', () {
      final c = Campaign.fromJson(campaignJson());
      expect(c.message, contains('नमस्ते'));
      expect(c.history, isEmpty);
      expect(c.isDraft, true);
      final sent = Campaign.fromJson(campaignJson(status: 'sent'));
      expect(sent.isSent, true);
      expect(sent.sentAt, isNotNull);
    });

    test('analysis result exposes AI source', () {
      expect(AnalysisResult.fromJson(analysisJson()).usedAi, false);
      expect(AnalysisResult.fromJson(analysisJson(source: 'ai')).usedAi, true);
      expect(AnalysisResult.fromJson(analysisJson()).draftCount, 1);
    });
  });
}
