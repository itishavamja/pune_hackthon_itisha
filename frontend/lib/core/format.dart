import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final NumberFormat _plain = NumberFormat.decimalPattern('en_IN');

/// ₹2,99,861 (Indian digit grouping)
String money(num v) => _inr.format(v);

/// 12,345 (Indian digit grouping, no symbol)
String count(num v) => _plain.format(v);

/// ₹1.2L / ₹12k for chart axes.
String moneyShort(num v) {
  final a = v.abs();
  if (a >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (a >= 1000) return '₹${(v / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

/// "-20.0%" / "+4.5%"
String signedPct(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}%';

String pct(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}%';

final DateFormat _dMon = DateFormat('d MMM');
final DateFormat _dMonTime = DateFormat('d MMM, h:mm a');

String dayMonth(DateTime d) => _dMon.format(d);
String dayMonthTime(DateTime d) => _dMonTime.format(d);

/// "2026-11-04" -> "4 Nov"
String dayMonthFromIso(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : _dMon.format(d);
}

String timeAgo(DateTime? t) {
  if (t == null) return '';
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _dMon.format(t);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
