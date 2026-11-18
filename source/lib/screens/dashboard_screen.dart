import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/models/app_models.dart';
import '../providers/app_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final sortedApps = [...state.apps]
      ..sort((a, b) => b.usageBytes.compareTo(a.usageBytes));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => state.refreshDeviceData(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
          children: [
            _Header(state: state),
            if (state.dataError != null) ...[
              const SizedBox(height: 16),
              _StatusBanner(
                  message: state.dataError!,
                  onAction: state.usageAccessGranted
                      ? null
                      : state.openUsageAccessSettings),
            ],
            const SizedBox(height: 20),
            _LiveMeterCard(state: state),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionHeader(title: 'السجل اليومي')),
                _PeriodSelector(state: state, ref: ref),
              ],
            ),
            const SizedBox(height: 10),
            _DailyChart(
                rows: state.chartRecords,
                periodLabel: state.selectedPeriodLabel,
                total: state.selectedPeriodTotalUsage),
            const SizedBox(height: 24),
            _SectionHeader(
                title: 'الأكثر استهلاكًا',
                action: state.apps.isEmpty ? null : 'من التطبيقات المثبتة'),
            const SizedBox(height: 10),
            if (sortedApps.isEmpty &&
                (state.isRefreshing || state.lastRefresh == null))
              const _LoadingDataCard()
            else if (sortedApps.isEmpty)
              const _EmptyDataCard()
            else
              ...sortedApps.take(3).map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopAppRow(app: app))),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مرحبًا بك',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('تحكم أوضح بإنترنتك',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(state.networkType,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => _showNotifications(context, state),
                tooltip: 'التنبيهات',
                style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              if (state.apps.any((app) => app.nearLimit) ||
                  state.dataError != null)
                Positioned(
                  right: 2,
                  top: 0,
                  child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle)),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.shield_outlined, color: AppColors.primary),
          ),
        ],
      );

  void _showNotifications(BuildContext context, AppState state) {
    final nearLimit = state.apps.where((app) => app.nearLimit).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('التنبيهات',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                if (state.dataError != null)
                  _NotificationRow(
                      icon: Icons.info_outline_rounded,
                      title: 'يحتاج التطبيق إلى انتباهك',
                      text: state.dataError!,
                      color: AppColors.warning),
                if (nearLimit.isEmpty && state.dataError == null)
                  const _NotificationRow(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'كل شيء تحت السيطرة',
                      text: 'لا توجد تطبيقات اقتربت من حدودها الحالية.',
                      color: AppColors.success),
                ...nearLimit.take(5).map((app) => _NotificationRow(
                    icon: Icons.data_usage_rounded,
                    title: '${app.name} اقترب من الحد',
                    text: 'الاستهلاك الحالي ${formatBytes(app.usageBytes)}.',
                    color: AppColors.warning)),
              ]),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.onAction});
  final String message;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.warning.withValues(alpha: .08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontSize: 12, height: 1.45))),
            if (onAction != null)
              TextButton(
                  onPressed: onAction, child: const Text('فتح الإعدادات')),
          ]),
        ),
      );
}

class _LiveMeterCard extends StatelessWidget {
  const _LiveMeterCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.speedServiceEnabled;
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('عداد السرعة والاستخدام اليومي',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800))),
            Text(state.networkType,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .72), fontSize: 11)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _LiveMeterValue(
                    label: 'التنزيل الآن',
                    value: formatRate(state.downloadKbps),
                    icon: Icons.arrow_downward_rounded)),
            Container(
                width: 1,
                height: 52,
                color: Colors.white.withValues(alpha: .18)),
            Expanded(
                child: _LiveMeterValue(
                    label: 'الرفع الآن',
                    value: formatRate(state.uploadKbps),
                    icon: Icons.arrow_upward_rounded)),
          ]),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: .18), height: 1),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _LiveUsageValue(
                    label: 'استخدام اليوم',
                    value: formatBytes(state.todayTotalUsage),
                    icon: Icons.data_usage_rounded)),
            Expanded(
                child: _LiveUsageValue(
                    label: 'Wi‑Fi',
                    value: formatBytes(state.todayWifiUsage),
                    icon: Icons.wifi_rounded)),
            Expanded(
                child: _LiveUsageValue(
                    label: 'الجوال',
                    value: formatBytes(state.todayMobileUsage),
                    icon: Icons.signal_cellular_alt_rounded)),
          ]),
          const SizedBox(height: 10),
          Text(
              active
                  ? 'يتحدث تلقائيًا من حركة الجهاز كل ثانية'
                  : 'فعّل عداد السرعة من الإعدادات ليعمل في الخلفية',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .68), fontSize: 10)),
        ]),
      ),
    );
  }
}

class _LiveMeterValue extends StatelessWidget {
  const _LiveMeterValue(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .70), fontSize: 10)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
      ]);
}

class _LiveUsageValue extends StatelessWidget {
  const _LiveUsageValue(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: AppColors.cyan, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .68), fontSize: 10)),
      ]);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800))),
        if (action != null)
          Text(action!,
              style: const TextStyle(color: AppColors.muted, fontSize: 11))
      ]);
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.state, required this.ref});
  final AppState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    const labels = ['يوم', 'أسبوع', 'شهر'];
    return SegmentedButton<int>(
      segments: [
        for (var i = 0; i < labels.length; i++)
          ButtonSegment<int>(value: i, label: Text(labels[i]))
      ],
      selected: {state.selectedPeriod},
      onSelectionChanged: (selected) =>
          ref.read(appStateProvider).setPeriod(selected.first),
      style: const ButtonStyle(
          textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          visualDensity: VisualDensity.compact),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart(
      {required this.rows, required this.periodLabel, required this.total});
  final List<DailyUsageRecord> rows;
  final String periodLabel;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyDataCard(message: 'لا توجد سجلات يومية متاحة بعد.');
    }
    final maxMegabytes = rows.fold<double>(
      0,
      (max, row) => max > row.totalBytes / (1024 * 1024)
          ? max
          : row.totalBytes / (1024 * 1024),
    );
    final chartMax = maxMegabytes == 0 ? 1.0 : maxMegabytes * 1.25;
    final interval = chartMax <= 4 ? 1.0 : chartMax / 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('الاستهلاك اليومي',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Text(periodLabel,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text('المجموع: ${formatBytes(total)} — كل عمود يمثل يومًا واحدًا',
                style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            const SizedBox(height: 12),
            SizedBox(
              height: 205,
              child: BarChart(
                BarChartData(
                  maxY: chartMax,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context).dividerColor, strokeWidth: .7),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final row = rows[group.x];
                        return BarTooltipItem(
                          '${_shortLabel(row.dateLabel)}\n${formatBytes(row.totalBytes)}',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          _axisLabel(value),
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.muted),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 29,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= rows.length) {
                            return const SizedBox.shrink();
                          }
                          final show = rows.length <= 8 ||
                              index == 0 ||
                              index == rows.length - 1 ||
                              index % 5 == 0;
                          if (!show) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_shortLabel(rows[index].dateLabel),
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.muted)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < rows.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: rows[index].totalBytes / (1024 * 1024),
                            width: rows.length > 12 ? 7 : 15,
                            borderRadius: BorderRadius.circular(4),
                            color: rows[index].totalBytes == 0
                                ? AppColors.border
                                : AppColors.primary,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                      'الاستهلاك بالميجابايت — اضغط على العمود لرؤية قيمته',
                      style: TextStyle(color: AppColors.muted, fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _axisLabel(double megabytes) {
    if (megabytes >= 1024) {
      return '${(megabytes / 1024).toStringAsFixed(1)} GB';
    }
    if (megabytes >= 1) return '${megabytes.toStringAsFixed(0)} MB';
    return '${(megabytes * 1024).toStringAsFixed(0)} KB';
  }

  static String _shortLabel(String value) =>
      value.length > 5 ? value.substring(value.length - 5) : value;
}

class _TopAppRow extends StatelessWidget {
  const _TopAppRow({required this.app});
  final ManagedApp app;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            _AppIcon(app: app),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(app.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(app.packageName,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10)),
                  const SizedBox(height: 8),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: app.limitBytes > 0 ? app.progress : null,
                          minHeight: 4,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: .10),
                          color: app.nearLimit
                              ? AppColors.warning
                              : AppColors.primary))
                ])),
            const SizedBox(width: 12),
            Text(formatBytes(app.usageBytes),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
      );
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});
  final ManagedApp app;

  @override
  Widget build(BuildContext context) => Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12)),
      child: app.iconBytes == null
          ? const Icon(Icons.apps_rounded, color: AppColors.primary)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(app.iconBytes!, fit: BoxFit.cover)));
}

class _LoadingDataCard extends StatelessWidget {
  const _LoadingDataCard();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .045),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('جاري قراءة التطبيقات والاستخدام من الهاتف',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 12, height: 1.4)),
            ),
          ]),
        ),
      );
}

class _EmptyDataCard extends StatelessWidget {
  const _EmptyDataCard(
      {this.message = 'لم تُكتشف تطبيقات أو بيانات على الجهاز بعد.'});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            const Icon(Icons.insights_outlined, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style:
                        const TextStyle(color: AppColors.muted, height: 1.4)))
          ])));
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow(
      {required this.icon,
      required this.title,
      required this.text,
      required this.color});
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(text,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 12, height: 1.35))
        ]))
      ]));
}
