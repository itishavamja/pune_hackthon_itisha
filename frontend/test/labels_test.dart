import 'package:dukaan360_app/core/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend jargon is translated into shopkeeper words', () {
    expect(segmentLabel('At Risk'), 'Stopped coming');
    expect(segmentLabel('Early Warning'), 'Coming less often');
    expect(segmentLabel('Active'), 'Coming regularly');
    expect(segmentLabel('New'), 'New customers');
    expect(segmentLabel('Something else'), 'Something else'); // unknown names pass through
    expect(riskLabel('HIGH'), 'Urgent');
    expect(riskLabel('MEDIUM'), 'Slowing down');
    expect(severityLabel('HIGH'), 'Serious');
    expect(severityLabel('MEDIUM'), 'Check this');
    expect(severityLabel('LOW'), 'Minor');
    expect(audienceLabel('At-risk regular customers'), 'Customers who stopped coming');
  });

  test('statistics terms are removed from text shown to the shopkeeper', () {
    const raw = 'On 05 Nov: amount Rs 4,000 is far above the usual ~Rs 398 (z-score 4.0) and it happened at 03:12.';
    final clean = cleanText(raw);
    expect(clean.contains('z-score'), false);
    expect(clean, contains('amount Rs 4,000'));
    expect(clean, contains('at 03:12'));
  });

  test('every kind of warning tells the shopkeeper what to do', () {
    for (final t in ['sales_decline', 'customer_churn', 'unusual_transaction', 'abnormal_transaction_count', 'unusual_revenue_change']) {
      expect(alertAdvice(t), startsWith('What to do:'), reason: t);
    }
    expect(alertAdvice('totally_new_type'), isNull);
  });
}
