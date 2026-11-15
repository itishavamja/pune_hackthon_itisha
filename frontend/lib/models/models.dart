// Plain data classes that mirror the backend JSON. Money is INR rupees (numbers).

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

/// The backend stores naive UTC timestamps (no "Z"). Parse them as UTC, show in local time.
DateTime? parseUtc(dynamic v) {
  if (v == null) return null;
  var s = v as String;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
  if (!hasZone) s = '${s}Z';
  return DateTime.tryParse(s)?.toLocal();
}

class Summary {
  Summary({
    required this.todayRevenue,
    required this.totalRevenue,
    required this.last7Revenue,
    required this.prev7Revenue,
    required this.growthPct,
    required this.totalCustomers,
    required this.atRiskCustomers,
    required this.alertsCount,
    required this.salesStatus,
    required this.lastAnalysisAt,
  });

  final double todayRevenue, totalRevenue, last7Revenue;
  final double? prev7Revenue, growthPct;
  final int totalCustomers, atRiskCustomers, alertsCount;
  final String salesStatus;
  final DateTime? lastAnalysisAt;

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        todayRevenue: _d(j['today_revenue']),
        totalRevenue: _d(j['total_revenue']),
        last7Revenue: _d(j['last_7_days_revenue']),
        prev7Revenue: _dn(j['previous_7_days_revenue']),
        growthPct: _dn(j['revenue_growth_percentage']),
        totalCustomers: _i(j['total_customers']),
        atRiskCustomers: _i(j['at_risk_customers']),
        alertsCount: _i(j['alerts_count']),
        salesStatus: (j['sales_status'] ?? 'unknown') as String,
        lastAnalysisAt: parseUtc(j['last_analysis_at']),
      );
}

class DayPoint {
  DayPoint(this.date, this.revenue);
  final DateTime date;
  final double revenue;
  factory DayPoint.fromJson(Map<String, dynamic> j) => DayPoint(DateTime.parse(j['date'] as String), _d(j['revenue']));
}

class Forecast {
  Forecast({
    required this.method,
    required this.salesStatus,
    required this.alertMessage,
    required this.changePct,
    required this.projectedChangePct,
    required this.predictedRevenue,
    required this.baselineRevenue,
    required this.history,
    required this.forecast,
  });

  final String? method;
  final String salesStatus;
  final String? alertMessage;
  final double? changePct, projectedChangePct, baselineRevenue;
  final double predictedRevenue;
  final List<DayPoint> history, forecast;

  bool get isDeclining => salesStatus == 'declining';

  factory Forecast.fromJson(Map<String, dynamic> j) => Forecast(
        method: j['method'] as String?,
        salesStatus: (j['sales_status'] ?? 'unknown') as String,
        alertMessage: j['alert_message'] as String?,
        changePct: _dn(j['revenue_change_percentage']),
        projectedChangePct: _dn(j['projected_change_percentage']),
        predictedRevenue: _d(j['predicted_revenue']),
        baselineRevenue: _dn(j['baseline_revenue']),
        history: [for (final e in (j['historical_sales'] as List)) DayPoint.fromJson(e as Map<String, dynamic>)],
        forecast: [for (final e in (j['forecast_sales'] as List)) DayPoint.fromJson(e as Map<String, dynamic>)],
      );
}

class Pagination {
  Pagination(this.total, this.limit, this.offset);
  final int total, limit, offset;
  factory Pagination.fromJson(Map<String, dynamic> j) => Pagination(_i(j['total']), _i(j['limit']), _i(j['offset']));
}

class ChurnSummary {
  ChurnSummary({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.atRiskCustomers,
    required this.earlyWarningCustomers,
    required this.inactive14Plus,
    required this.churnRiskPct,
    required this.averageBasket,
    required this.atRiskSpending,
  });

  final int totalCustomers, activeCustomers, atRiskCustomers, earlyWarningCustomers, inactive14Plus;
  final double churnRiskPct, averageBasket, atRiskSpending;

  factory ChurnSummary.fromJson(Map<String, dynamic> j) => ChurnSummary(
        totalCustomers: _i(j['total_customers']),
        activeCustomers: _i(j['active_customers']),
        atRiskCustomers: _i(j['at_risk_customers']),
        earlyWarningCustomers: _i(j['early_warning_customers']),
        inactive14Plus: _i(j['inactive_14_plus_days']),
        churnRiskPct: _d(j['churn_risk_percentage']),
        averageBasket: _d(j['average_basket_value']),
        atRiskSpending: _d(j['at_risk_total_spending']),
      );
}

class Segment {
  Segment(this.name, this.count);
  final String name;
  final int count;
  factory Segment.fromJson(Map<String, dynamic> j) => Segment(j['segment'] as String, _i(j['count']));
}

class AtRiskCustomer {
  AtRiskCustomer({
    required this.id,
    required this.name,
    required this.lastVisit,
    required this.daysInactive,
    required this.totalSpending,
    required this.visitCount,
    required this.normalIntervalDays,
    required this.riskLevel,
  });

  final int id, visitCount;
  final String name, riskLevel;
  final String? lastVisit;
  final int? daysInactive;
  final double totalSpending;
  final double? normalIntervalDays;

  bool get isHigh => riskLevel == 'HIGH';

  factory AtRiskCustomer.fromJson(Map<String, dynamic> j) => AtRiskCustomer(
        id: _i(j['customer_id']),
        name: j['customer_name'] as String,
        lastVisit: j['last_visit'] as String?,
        daysInactive: j['days_inactive'] == null ? null : _i(j['days_inactive']),
        totalSpending: _d(j['total_spending']),
        visitCount: _i(j['visit_count']),
        normalIntervalDays: _dn(j['normal_visit_interval_days']),
        riskLevel: (j['risk_level'] ?? 'LOW') as String,
      );
}

class ChurnPage {
  ChurnPage({required this.summary, required this.segments, required this.customers, required this.pagination});
  final ChurnSummary summary;
  final List<Segment> segments;
  final List<AtRiskCustomer> customers;
  final Pagination pagination;

  factory ChurnPage.fromJson(Map<String, dynamic> j) => ChurnPage(
        summary: ChurnSummary.fromJson(j['summary'] as Map<String, dynamic>),
        segments: [for (final e in (j['customer_segments'] as List)) Segment.fromJson(e as Map<String, dynamic>)],
        customers: [for (final e in (j['at_risk_customers'] as List)) AtRiskCustomer.fromJson(e as Map<String, dynamic>)],
        pagination: Pagination.fromJson(j['pagination'] as Map<String, dynamic>),
      );
}

class AlertItem {
  AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.metricValue,
    required this.createdAt,
  });

  final int id;
  final String type, severity, title, description;
  final String? metricValue;
  final DateTime? createdAt;

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: _i(j['id']),
        type: j['alert_type'] as String,
        severity: j['severity'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        metricValue: j['metric_value'] as String?,
        createdAt: parseUtc(j['created_at']),
      );
}

class AlertsPage {
  AlertsPage(this.alerts, this.pagination);
  final List<AlertItem> alerts;
  final Pagination pagination;
  factory AlertsPage.fromJson(Map<String, dynamic> j) => AlertsPage(
        [for (final e in (j['alerts'] as List)) AlertItem.fromJson(e as Map<String, dynamic>)],
        Pagination.fromJson(j['pagination'] as Map<String, dynamic>),
      );
}

class HistoryEntry {
  HistoryEntry(this.action, this.previous, this.next, this.at);
  final String action;
  final String? previous;
  final String next;
  final DateTime? at;
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        j['action'] as String,
        j['previous_status'] as String?,
        j['new_status'] as String,
        parseUtc(j['action_timestamp']),
      );
}

class Campaign {
  Campaign({
    required this.id,
    required this.title,
    required this.type,
    required this.segment,
    required this.targetCount,
    required this.language,
    required this.message,
    required this.objective,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.approvedAt,
    required this.sentAt,
    required this.history,
  });

  final int id, targetCount;
  final String? title, objective, reason;
  final String type, segment, language, message, status;
  final DateTime? createdAt, approvedAt, sentAt;
  final List<HistoryEntry> history;

  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isRejected => status == 'rejected';
  String get displayTitle => (title == null || title!.trim().isEmpty) ? 'Campaign #$id' : title!;

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: _i(j['id']),
        title: j['title'] as String?,
        type: j['campaign_type'] as String,
        segment: j['segment'] as String,
        targetCount: _i(j['target_customer_count']),
        language: j['language'] as String,
        message: j['message'] as String,
        objective: j['objective'] as String?,
        reason: j['reason'] as String?,
        status: j['status'] as String,
        createdAt: parseUtc(j['created_at']),
        approvedAt: parseUtc(j['approved_at']),
        sentAt: parseUtc(j['sent_at']),
        history: [
          for (final e in ((j['history'] as List?) ?? const [])) HistoryEntry.fromJson(e as Map<String, dynamic>)
        ],
      );
}

class CampaignsPage {
  CampaignsPage(this.campaigns, this.pagination);
  final List<Campaign> campaigns;
  final Pagination pagination;
  factory CampaignsPage.fromJson(Map<String, dynamic> j) => CampaignsPage(
        [for (final e in (j['campaigns'] as List)) Campaign.fromJson(e as Map<String, dynamic>)],
        Pagination.fromJson(j['pagination'] as Map<String, dynamic>),
      );
}

class ActionResult {
  ActionResult(this.campaign, this.message, this.alreadyProcessed, this.demoMode);
  final Campaign campaign;
  final String message;
  final bool alreadyProcessed, demoMode;
  factory ActionResult.fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return ActionResult(
      Campaign.fromJson(m['campaign'] as Map<String, dynamic>),
      m['message'] as String,
      (m['already_processed'] ?? false) as bool,
      (m['demo_mode'] ?? true) as bool,
    );
  }
}

/// Result of POST /analyze. The numeric sections are kept as raw maps because the app only
/// displays them through the dedicated dashboard endpoints.
class AnalysisResult {
  AnalysisResult({
    required this.runId,
    required this.generatedAt,
    required this.replayed,
    required this.explanationText,
    required this.explanationSource,
    required this.language,
    required this.warnings,
    required this.draftCount,
    required this.raw,
  });

  final int runId;
  final DateTime? generatedAt;
  final bool replayed;
  final String? explanationText, explanationSource, language;
  final List<String> warnings;
  final int draftCount;
  final Map<String, dynamic> raw;

  bool get usedAi => explanationSource == 'ai';

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final ai = (j['ai_explanation'] as Map<String, dynamic>?) ?? const {};
    return AnalysisResult(
      runId: _i(j['analysis_run_id']),
      generatedAt: parseUtc(j['generated_at']),
      replayed: (j['replayed'] ?? false) as bool,
      explanationText: ai['text'] as String?,
      explanationSource: ai['source'] as String?,
      language: ai['language'] as String?,
      warnings: [for (final w in ((j['warnings'] as List?) ?? const [])) w as String],
      draftCount: ((j['campaign_drafts'] as List?) ?? const []).length,
      raw: j,
    );
  }
}

class AskResult {
  AskResult(this.answer, this.source);
  final String answer;
  final String source; // "ai" | "fallback"
  factory AskResult.fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return AskResult(m['answer'] as String, m['source'] as String);
  }
}
