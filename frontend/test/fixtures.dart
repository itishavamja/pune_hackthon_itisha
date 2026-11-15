import 'package:dukaan360_app/core/api_client.dart';
import 'package:dukaan360_app/models/models.dart';

/// Sample backend JSON (shapes copied from the real FastAPI responses).
Map<String, dynamic> summaryJson() => {
      'currency': 'INR',
      'today_revenue': 10940.0,
      'total_revenue': 1150730.0,
      'last_7_days_revenue': 60029.0,
      'previous_7_days_revenue': 75012.0,
      'revenue_growth_percentage': -19.97,
      'total_customers': 150,
      'at_risk_customers': 29,
      'alerts_count': 5,
      'sales_status': 'declining',
      'last_analysis_at': '2026-11-14T18:04:46.309534',
    };

Map<String, dynamic> forecastJson() => {
      'currency': 'INR',
      'method': 'holt_winters_exponential_smoothing',
      'sales_status': 'declining',
      'alert_message': 'Sales decline warning: revenue in the last 7 days (Rs 60,029) is 20.0% lower than the 7 days before.',
      'revenue_change_percentage': -19.97,
      'projected_change_percentage': -30.31,
      'predicted_revenue': 67118.71,
      'baseline_revenue': 96309.25,
      'historical_sales': [
        for (var i = 0; i < 30; i++) {'date': '2026-10-${(i + 1).toString().padLeft(2, '0')}', 'revenue': 12000.0 + i * 100}
      ],
      'forecast_sales': [
        for (var i = 0; i < 7; i++) {'date': '2026-11-${(i + 15).toString().padLeft(2, '0')}', 'revenue': 9500.0 + i * 50}
      ],
      'actual_vs_predicted': [],
    };

Map<String, dynamic> churnJson({int offset = 0}) => {
      'summary': {
        'total_customers': 150,
        'active_customers': 121,
        'at_risk_customers': 29,
        'early_warning_customers': 20,
        'inactive_14_plus_days': 32,
        'churn_risk_percentage': 19.33,
        'average_basket_value': 525.66,
        'at_risk_total_spending': 299861.0,
      },
      'customer_segments': [
        {'segment': 'Active', 'count': 76},
        {'segment': 'Early Warning', 'count': 20},
        {'segment': 'At Risk', 'count': 29},
        {'segment': 'New', 'count': 25},
      ],
      'at_risk_customers': [
        {
          'customer_id': 129,
          'customer_name': 'Manisha Wagh',
          'last_visit': '2026-10-26',
          'days_inactive': 19,
          'total_spending': 20588.0,
          'visit_count': 31,
          'normal_visit_interval_days': 2.0,
          'segment': 'At Risk',
          'risk_level': 'HIGH',
        },
        {
          'customer_id': 135,
          'customer_name': 'Aarav Thakur',
          'last_visit': '2026-10-19',
          'days_inactive': 26,
          'total_spending': 16806.0,
          'visit_count': 29,
          'normal_visit_interval_days': 1.5,
          'segment': 'At Risk',
          'risk_level': 'MEDIUM',
        },
      ],
      'pagination': {'total': 2, 'limit': 20, 'offset': offset},
    };

Map<String, dynamic> alertsJson() => {
      'alerts': [
        {
          'id': 1,
          'alert_type': 'sales_decline',
          'severity': 'HIGH',
          'title': 'Sales Decline Warning',
          'description': 'Revenue is down 20% versus last week.',
          'metric_value': '-30.3%',
          'created_at': '2026-11-14T18:04:46',
        },
        {
          'id': 2,
          'alert_type': 'unusual_transaction',
          'severity': 'MEDIUM',
          'title': 'Unusual Activity Detected',
          'description': 'Amount Rs 12,000 is far above the usual.',
          'metric_value': '12000.0',
          'created_at': '2026-11-14T18:04:46',
        },
      ],
      'pagination': {'total': 2, 'limit': 100, 'offset': 0},
    };

Map<String, dynamic> campaignJson({int id = 1, String status = 'draft', List<Map<String, dynamic>>? history}) => {
      'id': id,
      'title': 'वापसी का खास ऑफर',
      'campaign_type': 'win_back',
      'segment': 'At-risk regular customers',
      'target_customer_count': 29,
      'language': 'Hindi',
      'message': 'नमस्ते! हमें आपकी कमी खल रही है। इस हफ्ते आइए और खास ऑफर पाइए!',
      'objective': 'Customer retention',
      'reason': '29 regular customers have not visited for 14 or more days.',
      'status': status,
      'created_at': '2026-11-14T18:04:46',
      'approved_at': status == 'draft' ? null : '2026-11-14T18:10:00',
      'sent_at': status == 'sent' ? '2026-11-14T18:10:01' : null,
      if (history != null) 'history': history,
    };

Map<String, dynamic> analysisJson({String source = 'fallback'}) => {
      'analysis_run_id': 2,
      'merchant_id': 1,
      'generated_at': '2026-11-14T18:04:46',
      'replayed': false,
      'sales_insights': {'sales_status': 'declining'},
      'customer_insights': {'at_risk_customers': 29},
      'business_risk_insights': {'alert_count': 3},
      'ai_explanation': {
        'text': 'आपकी बिक्री पिछले हफ्ते से लगभग 20% कम है।',
        'source': source,
        'language': 'Hindi',
      },
      'campaign_drafts': [campaignJson()],
      'warnings': source == 'fallback' ? ['AI service unavailable - template wording was used.'] : [],
    };

/// In-memory stand-in for the backend, so widget tests need no server.
class FakeApi extends ApiClient {
  FakeApi({this.offline = false}) : super('http://fake');

  bool offline;
  String campaignStatus = 'draft';
  int approveCalls = 0;
  String? lastEditMessage;

  void _check() {
    if (offline) throw ApiException(message: "Can't reach the server.", isNetwork: true, code: 'network');
  }

  @override
  Future<Summary> summary() async {
    _check();
    return Summary.fromJson(summaryJson());
  }

  @override
  Future<Forecast> forecast({int historyDays = 30}) async {
    _check();
    return Forecast.fromJson(forecastJson());
  }

  @override
  Future<ChurnPage> churn({int limit = 20, int offset = 0, String? riskLevel}) async {
    _check();
    return ChurnPage.fromJson(churnJson(offset: offset));
  }

  @override
  Future<AlertsPage> alerts({int limit = 100, int offset = 0, String? severity}) async {
    _check();
    return AlertsPage.fromJson(alertsJson());
  }

  @override
  Future<CampaignsPage> campaigns({int limit = 100, int offset = 0, String? status}) async {
    _check();
    return CampaignsPage.fromJson({
      'campaigns': [campaignJson(status: campaignStatus)],
      'pagination': {'total': 1, 'limit': limit, 'offset': offset},
    });
  }

  @override
  Future<Campaign> campaign(int id) async => Campaign.fromJson(campaignJson(id: id, status: campaignStatus, history: [
        {'id': 1, 'action': 'created', 'previous_status': null, 'new_status': 'draft', 'action_timestamp': '2026-11-14T18:04:46'},
      ]));

  @override
  Future<Campaign> editCampaign(int id, {String? title, String? message}) async {
    lastEditMessage = message;
    return Campaign.fromJson(campaignJson(id: id));
  }

  @override
  Future<ActionResult> approve(int id) async {
    approveCalls++;
    final already = campaignStatus == 'sent';
    campaignStatus = 'sent';
    return ActionResult.fromJson({
      'campaign': campaignJson(id: id, status: 'sent'),
      'message': already
          ? 'This campaign was already sent (Demo Mode). No duplicate message was sent.'
          : 'Campaign sent successfully (Demo Mode).',
      'already_processed': already,
      'demo_mode': true,
    });
  }

  @override
  Future<AnalysisResult> analyze({required String language, required String idempotencyKey}) async {
    _check();
    return AnalysisResult.fromJson(analysisJson());
  }

  @override
  Future<AskResult> ask(String question, String language) async =>
      AskResult('29 regular customers have not visited for 14 or more days.', 'fallback');
}
