import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Revenue history (solid) + 7-day forecast (dashed), drawn from the backend's data.
class ForecastChart extends StatelessWidget {
  const ForecastChart({super.key, required this.data});
  final Forecast data;

  @override
  Widget build(BuildContext context) {
    final hist = data.history;
    final fc = data.forecast;
    if (hist.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('Not enough sales history yet', style: TextStyle(color: context.muted))),
      );
    }

    final all = [...hist, ...fc];
    final n = hist.length;
    final actualSpots = [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), hist[i].revenue)];
    final forecastSpots = [
      FlSpot((n - 1).toDouble(), hist.last.revenue), // join the two lines
      for (var j = 0; j < fc.length; j++) FlSpot((n + j).toDouble(), fc[j].revenue),
    ];
    final maxV = all.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    final maxY = (maxV * 1.18).ceilToDouble();
    final step = (all.length / 5).ceil().clamp(1, 100);
    final primary = context.cs.primary;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (all.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: context.hairline, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: maxY / 4,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(moneyShort(v),
                        textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: context.muted)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= all.length || i % step != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(dayMonth(all[i].date), style: TextStyle(fontSize: 10.5, color: context.muted)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(verticalLines: [
            VerticalLine(
              x: (n - 1).toDouble(),
              color: context.muted.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: [3, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 4),
                style: TextStyle(fontSize: 10, color: context.muted, fontWeight: FontWeight.w700),
                labelResolver: (_) => 'Next 7 days →',
              ),
            ),
          ]),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Brand.navy,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${dayMonth(all[s.x.toInt().clamp(0, all.length - 1)].date)}\n${money(s.y)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: actualSpots,
              isCurved: true,
              curveSmoothness: 0.22,
              color: primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primary.withValues(alpha: 0.28), primary.withValues(alpha: 0.0)],
                ),
              ),
            ),
            LineChartBarData(
              spots: forecastSpots,
              isCurved: true,
              curveSmoothness: 0.22,
              color: Brand.amber,
              barWidth: 3,
              dashArray: [7, 5],
              dotData: FlDotData(
                show: true,
                checkToShowDot: (s, _) => s.x > n - 1,
                getDotPainter: (s, p, b, i) =>
                    FlDotCirclePainter(radius: 3.2, color: Brand.amber, strokeWidth: 1.5, strokeColor: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
