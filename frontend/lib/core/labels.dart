// Plain, shopkeeper-friendly wording. The backend uses technical names ("At Risk", "HIGH",
// "z-score"); the app translates them here so nothing on screen needs explaining.

String segmentLabel(String backendName) => switch (backendName) {
      'Active' => 'Coming regularly',
      'Early Warning' => 'Coming less often',
      'At Risk' => 'Stopped coming',
      'New' => 'New customers',
      _ => backendName,
    };

/// Who a campaign is for.
String audienceLabel(String backendName) => switch (backendName) {
      'At-risk regular customers' => 'Customers who stopped coming',
      'Active customers' => 'Your regular customers',
      'Low average-bill customers' => 'Customers with small bills',
      _ => backendName,
    };

String riskLabel(String level) => level == 'HIGH' ? 'Urgent' : 'Slowing down';

String severityLabel(String s) => switch (s.toUpperCase()) {
      'HIGH' => 'Serious',
      'MEDIUM' => 'Check this',
      _ => 'Minor',
    };

/// Removes statistics jargon such as "(z-score 8.3)" from backend text.
String cleanText(String s) => s.replaceAll(RegExp(r'\s*\(z-score[^)]*\)'), '').replaceAll('  ', ' ');

/// One line telling the shopkeeper what they can do about a warning.
String? alertAdvice(String type) => switch (type) {
      'sales_decline' => 'What to do: open the Offers tab and send a message to bring customers back.',
      'customer_churn' => 'What to do: open Customers to see who stopped coming, then send them an offer.',
      'unusual_transaction' =>
        'What to do: check this payment in your records. It may be fine, for example a big order.',
      'abnormal_transaction_count' || 'unusual_revenue_change' =>
        'What to do: think about what happened that day (a festival, a big order, a holiday).',
      _ => null,
    };
