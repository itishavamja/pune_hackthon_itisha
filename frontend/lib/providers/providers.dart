import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/models.dart';

// ---------------------------------------------------------------- app-wide
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main()'));

final apiUrlProvider = StateProvider<String>(
  (ref) => ref.read(sharedPrefsProvider).getString(kPrefApiUrl) ?? defaultApiUrl(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final c = ApiClient(ref.watch(apiUrlProvider));
  ref.onDispose(c.close);
  return c;
});

/// Bottom navigation: 0 Home, 1 Customers, 2 Alerts, 3 Growth.
final navIndexProvider = StateProvider<int>((ref) => 0);

final languageProvider = StateProvider<String>(
  (ref) => ref.read(sharedPrefsProvider).getString(kPrefLanguage) ?? 'Hindi',
);

// ---------------------------------------------------------------- dashboard
final summaryProvider = FutureProvider<Summary>((ref) => ref.watch(apiClientProvider).summary());

/// True while the backend cannot be reached (used for the offline banner and auto-retry).
final offlineProvider = Provider<bool>((ref) {
  final s = ref.watch(summaryProvider);
  final e = s.error;
  return s.hasError && e is ApiException && e.isNetwork;
});

final forecastRangeProvider = StateProvider<int>((ref) => 30);

final forecastProvider = FutureProvider<Forecast>(
  (ref) => ref.watch(apiClientProvider).forecast(historyDays: ref.watch(forecastRangeProvider)),
);

// ---------------------------------------------------------------- customers (paginated)
final churnFilterProvider = StateProvider<String?>((ref) => null); // null | HIGH | MEDIUM

class ChurnState {
  const ChurnState({
    this.summary,
    this.segments = const [],
    this.items = const [],
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final ChurnSummary? summary;
  final List<Segment> segments;
  final List<AtRiskCustomer> items;
  final int total;
  final bool loading, loadingMore;
  final ApiException? error;

  bool get hasMore => items.length < total;

  ChurnState copyWith({bool? loading, bool? loadingMore, ApiException? error, bool clearError = false}) => ChurnState(
        summary: summary,
        segments: segments,
        items: items,
        total: total,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChurnNotifier extends Notifier<ChurnState> {
  static const _pageSize = 20;
  late ApiClient _api;
  String? _filter;
  bool _disposed = false;

  @override
  ChurnState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _api = ref.watch(apiClientProvider);
    _filter = ref.watch(churnFilterProvider);
    Future.microtask(() => _fetch(more: false));
    return const ChurnState(loading: true);
  }

  Future<void> refresh() => _fetch(more: false);
  Future<void> loadMore() => _fetch(more: true);

  Future<void> _fetch({required bool more}) async {
    final s = state;
    if (more) {
      if (s.loadingMore || !s.hasMore) return;
      state = s.copyWith(loadingMore: true, clearError: true);
    }
    try {
      final page = await _api.churn(limit: _pageSize, offset: more ? s.items.length : 0, riskLevel: _filter);
      if (_disposed) return;
      state = ChurnState(
        summary: page.summary,
        segments: page.segments,
        items: more ? [...s.items, ...page.customers] : page.customers,
        total: page.pagination.total,
      );
    } on ApiException catch (e) {
      if (_disposed) return;
      state = s.copyWith(loading: false, loadingMore: false, error: e);
    }
  }
}

final churnProvider = NotifierProvider<ChurnNotifier, ChurnState>(ChurnNotifier.new);

// ---------------------------------------------------------------- alerts
final alertSeverityProvider = StateProvider<String?>((ref) => null); // null | HIGH | MEDIUM | LOW

final alertsProvider = FutureProvider<AlertsPage>(
  (ref) => ref.watch(apiClientProvider).alerts(severity: ref.watch(alertSeverityProvider)),
);

// ---------------------------------------------------------------- campaigns
final campaignsProvider = FutureProvider<CampaignsPage>((ref) => ref.watch(apiClientProvider).campaigns());

final campaignDetailProvider = FutureProvider.autoDispose.family<Campaign, int>(
  (ref, id) => ref.watch(apiClientProvider).campaign(id),
);

// ---------------------------------------------------------------- analysis
class AnalysisState {
  const AnalysisState({this.result, this.running = false, this.error});
  final AnalysisResult? result;
  final bool running;
  final ApiException? error;
}

/// Everything that depends on the latest analysis / data. Call with `ref.invalidate`.
final List<ProviderOrFamily> dataProviders = [
  summaryProvider,
  forecastProvider,
  churnProvider,
  alertsProvider,
  campaignsProvider,
];

void invalidateAll(void Function(ProviderOrFamily) invalidate) {
  for (final p in dataProviders) {
    invalidate(p);
  }
}

class AnalysisNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() {
    // Restore the last analysis so the AI explanation survives an app restart.
    final raw = ref.read(sharedPrefsProvider).getString(kPrefLastAnalysis);
    AnalysisResult? cached;
    if (raw != null) {
      try {
        cached = AnalysisResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        cached = null;
      }
    }
    return AnalysisState(result: cached);
  }

  /// Runs POST /analyze. Returns the result, or null on failure (see `state.error`).
  Future<AnalysisResult?> run() async {
    if (state.running) return null;
    state = AnalysisState(result: state.result, running: true);
    try {
      final r = await ref.read(apiClientProvider).analyze(
            language: ref.read(languageProvider),
            idempotencyKey: 'app-${DateTime.now().microsecondsSinceEpoch}',
          );
      await ref.read(sharedPrefsProvider).setString(kPrefLastAnalysis, jsonEncode(r.raw));
      state = AnalysisState(result: r);
      invalidateAll(ref.invalidate);
      return r;
    } on ApiException catch (e) {
      state = AnalysisState(result: state.result, error: e);
      return null;
    }
  }
}

final analysisProvider = NotifierProvider<AnalysisNotifier, AnalysisState>(AnalysisNotifier.new);
