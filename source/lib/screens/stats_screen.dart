import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../data/models/app_models.dart';
import '../providers/app_state.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          const Text('الإحصائيات والشبكة',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('قراءات فعلية عندما يسمح Android بالصلاحيات المطلوبة.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 20),
          _LiveSpeedCard(state: state),
          const SizedBox(height: 14),
          _StatsActions(state: state, ref: ref),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'ملخص الاستخدام'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _MetricTile(
                    label: 'إجمالي الاستخدام اليوم',
                    value: formatBytes(state.todayTotalUsage),
                    icon: Icons.data_usage_rounded,
                    color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: _MetricTile(
                    label: 'متوسط ${state.selectedPeriodLabel}',
                    value: formatBytes(state.selectedPeriodAverage.toInt()),
                    icon: Icons.today_rounded,
                    color: AppColors.teal)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _MetricTile(
                    label: 'Wi‑Fi اليوم',
                    value: formatBytes(state.todayWifiUsage),
                    icon: Icons.wifi_rounded,
                    color: AppColors.cyan)),
            const SizedBox(width: 12),
            Expanded(
                child: _MetricTile(
                    label: 'الجوال اليوم',
                    value: formatBytes(state.todayMobileUsage),
                    icon: Icons.signal_cellular_alt_rounded,
                    color: AppColors.warning)),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: _SectionTitle(title: 'ملخص الفترة')),
            Text(state.selectedPeriodLabel,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          _PeriodSummarySelector(state: state, ref: ref),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _MetricTile(
                    label: 'الإجمالي',
                    value: formatBytes(state.selectedPeriodTotalUsage),
                    icon: Icons.insights_rounded,
                    color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: _MetricTile(
                    label: 'Wi‑Fi الفترة',
                    value: formatBytes(state.selectedPeriodWifiUsage),
                    icon: Icons.wifi_find_rounded,
                    color: AppColors.teal)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _MetricTile(
                    label: 'الجوال الفترة',
                    value: formatBytes(state.selectedPeriodMobileUsage),
                    icon: Icons.signal_cellular_alt_rounded,
                    color: AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(
                child: _MetricTile(
                    label: 'الأيام المقروءة',
                    value:
                        '${state.selectedPeriodRecords.length} من ${state.selectedPeriodDays}',
                    icon: Icons.event_available_rounded,
                    color: AppColors.teal)),
          ]),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'السجل اليومي'),
          const SizedBox(height: 10),
          _DailyUsageTable(
              records: state.dailyRecords, apps: state.apps, state: state),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'التوزيع حسب التطبيق'),
          const SizedBox(height: 10),
          _UsageDistribution(apps: state.apps),
        ],
      ),
    );
  }
}

class _LiveSpeedCard extends StatelessWidget {
  const _LiveSpeedCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('العداد المباشر',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))),
              Text(
                  state.speedServiceEnabled
                      ? 'خدمة الخلفية مفعلة'
                      : 'الخدمة غير مفعلة',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .72), fontSize: 11))
            ]),
            const SizedBox(height: 8),
            Text(state.networkType,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .72), fontSize: 12)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _SpeedMetric(
                      icon: Icons.download_rounded,
                      label: 'تنزيل',
                      value: formatRate(state.downloadKbps))),
              Expanded(
                  child: _SpeedMetric(
                      icon: Icons.upload_rounded,
                      label: 'رفع',
                      value: formatRate(state.uploadKbps))),
              Expanded(
                  child: _SpeedMetric(
                      icon: Icons.trending_up_rounded,
                      label: 'الذروة',
                      value: formatRate(state.peakDownloadKbps))),
            ]),
            const SizedBox(height: 18),
            SizedBox(
                height: 60,
                child: _SpeedHistory(values: state.downloadHistory)),
            const SizedBox(height: 8),
            Text(
                'يتم الحساب من عداد حركة الجهاز كل ثانية، وليس من اختبار سرعة.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .68), fontSize: 11)),
          ]),
        ),
      );
}

class _SpeedMetric extends StatelessWidget {
  const _SpeedMetric(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        const Icon(Icons.circle, color: AppColors.cyan, size: 7),
        const SizedBox(height: 7),
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .72), fontSize: 10)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center)
      ]);
}

class _SpeedHistory extends StatelessWidget {
  const _SpeedHistory({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Center(
          child: Text('شغّل عداد الخلفية لرؤية تغير السرعة',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .65), fontSize: 11)));
    }
    final maxValue =
        values.fold<double>(1, (max, value) => value > max ? value : max);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxValue * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
            isCurved: true,
            color: AppColors.cyan,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
                show: true, color: AppColors.cyan.withValues(alpha: .12)),
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i])
            ])
      ],
    ));
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14))
                ]))
          ])));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800));
}

class _PeriodSummarySelector extends StatelessWidget {
  const _PeriodSummarySelector({required this.state, required this.ref});
  final AppState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    const labels = ['يوم', 'أسبوع', 'شهر'];
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: [
          for (var index = 0; index < labels.length; index++)
            ButtonSegment<int>(value: index, label: Text(labels[index])),
        ],
        selected: {state.selectedPeriod},
        onSelectionChanged: (selected) =>
            ref.read(appStateProvider).setPeriod(selected.first),
        style: const ButtonStyle(
            textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            visualDensity: VisualDensity.compact),
      ),
    );
  }
}

class _StatsActions extends StatelessWidget {
  const _StatsActions({required this.state, required this.ref});
  final AppState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmResetToday(context),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('تصفير اليوم'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmResetAll(context),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('تصفير الإحصاءات'),
          ),
        ),
      ]);

  Future<void> _confirmResetToday(BuildContext context) async {
    final confirmed = await _confirm(context, 'تصفير استخدام اليوم؟',
        'سيبدأ عداد اليوم من الصفر، مع إبقاء الأيام السابقة في السجل.');
    if (confirmed != true) return;
    await ref.read(appStateProvider).resetTodayStats();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بدأ عداد اليوم من الصفر')));
    }
  }

  Future<void> _confirmResetAll(BuildContext context) async {
    final confirmed = await _confirm(context, 'تصفير كل الإحصاءات؟',
        'ستبدأ فترة قراءة جديدة وستُمسح سجلات الفترة الحالية من داخل التطبيق.');
    if (confirmed != true) return;
    await ref.read(appStateProvider).resetStats();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصفير الإحصاءات وبدء فترة جديدة')));
    }
  }

  Future<bool?> _confirm(BuildContext context, String title, String message) =>
      showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('تأكيد')),
                ],
              ));
}

class _DailyUsageTable extends StatelessWidget {
  const _DailyUsageTable(
      {required this.records, required this.apps, required this.state});
  final List<DailyUsageRecord> records;
  final List<ManagedApp> apps;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyCard(
          message:
              'لا توجد سجلات يومية حقيقية بعد. امنح التطبيق إذن الاستخدام ثم أعد التحديث.');
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: const Row(children: [
              Expanded(
                  child: Text('التاريخ',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              Expanded(
                  child: Text('جوال',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              Expanded(
                  child: Text('Wi‑Fi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              Expanded(
                  child: Text('المجموع',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)))
            ])),
        Container(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: .055),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            child: const Row(children: [
              Icon(Icons.touch_app_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 7),
              Expanded(
                  child: Text('اضغط على أي يوم لعرض تفاصيل التطبيقات',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.primary),
            ])),
        for (var i = 0; i < records.length; i++) ...[
          InkWell(
            onTap: () => _showDayDetails(context, records[i], apps, state),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              child: Row(children: [
                Expanded(
                    flex: 2,
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(records[i].dateLabel,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700))),
                    ])),
                Expanded(
                    child: Text(formatBytes(records[i].mobileBytes),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11))),
                Expanded(
                    child: Text(formatBytes(records[i].wifiBytes),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11))),
                Expanded(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                      Text(formatBytes(records[i].totalBytes),
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_left_rounded,
                          size: 17, color: AppColors.muted),
                    ]))
              ]),
            ),
          ),
          if (i != records.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

void _showDayDetails(BuildContext context, DailyUsageRecord record,
    List<ManagedApp> apps, AppState state) {
  final appsByPackage = <String, ManagedApp>{
    for (final app in apps) app.packageName: app,
  };
  final rows = record.appUsage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفاصيل يوم ${record.dateLabel}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('تفصيل الاستهلاك المسجل من Android لهذا اليوم',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 12),
              _DayUsageSummary(record: record),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmResetDay(
                    context, sheetContext, state, record.dateLabel),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('تصفير بيانات هذا اليوم'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: .35))),
              ),
              const SizedBox(height: 8),
              const Text(
                  'سيبدأ عداد هذا اليوم من الصفر، مع بقاء القياس الأصلي لدى Android.',
                  style: TextStyle(color: AppColors.muted, fontSize: 10)),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(
                  child: Text('استهلاك التطبيقات',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Text('${rows.length} تطبيق',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
              ]),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const _EmptyCard(
                    message: 'لا تتوفر تفاصيل UID لهذا اليوم من Android.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final packages = row.key.split(' + ');
                      final label = packages
                          .map((part) => appsByPackage[part]?.name ?? part)
                          .join(' + ');
                      final iconApp = _firstIconApp(packages, appsByPackage);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          _HistoryAppIcon(app: iconApp),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(
                                    packages.length > 1
                                        ? 'مجموعة UID مشتركة'
                                        : row.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 10)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatBytes(row.value),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              const SizedBox(height: 3),
                              const Text('استهلاك',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 10)),
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _confirmResetDay(BuildContext context, BuildContext sheetContext,
    AppState state, String dateLabel) async {
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تصفير بيانات هذا اليوم؟'),
      content: const Text(
          'سيتم إخفاء الاستهلاك الحالي لهذا التاريخ داخل التطبيق وبدء عداد جديد له. لا يمكن للتطبيق حذف السجل الأصلي من Android.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تصفير')),
      ],
    ),
  );
  if (confirmed != true) return;
  await state.resetDayStats(dateLabel);
  if (sheetContext.mounted) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم تصفير بيانات اليوم')));
  }
}

ManagedApp? _firstIconApp(
    List<String> packages, Map<String, ManagedApp> appsByPackage) {
  for (final packageName in packages) {
    final app = appsByPackage[packageName];
    if (app?.iconBytes != null) return app;
  }
  for (final packageName in packages) {
    final app = appsByPackage[packageName];
    if (app != null) return app;
  }
  return null;
}

class _DayUsageSummary extends StatelessWidget {
  const _DayUsageSummary({required this.record});
  final DailyUsageRecord record;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(children: [
            Expanded(
                child: _DayUsageStat(
                    label: 'المجموع',
                    value: formatBytes(record.totalBytes),
                    icon: Icons.data_usage_rounded,
                    color: AppColors.primary)),
            Expanded(
                child: _DayUsageStat(
                    label: 'Wi‑Fi',
                    value: formatBytes(record.wifiBytes),
                    icon: Icons.wifi_rounded,
                    color: AppColors.cyan)),
            Expanded(
                child: _DayUsageStat(
                    label: 'الجوال',
                    value: formatBytes(record.mobileBytes),
                    icon: Icons.signal_cellular_alt_rounded,
                    color: AppColors.warning)),
          ]),
        ),
      );
}

class _DayUsageStat extends StatelessWidget {
  const _DayUsageStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 5),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      ]);
}

class _HistoryAppIcon extends StatelessWidget {
  const _HistoryAppIcon({required this.app});
  static const size = 42.0;
  final ManagedApp? app;

  @override
  Widget build(BuildContext context) {
    final iconBytes = app?.iconBytes;
    if (iconBytes != null && iconBytes.isNotEmpty) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.memory(iconBytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon()));
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(app?.icon ?? Icons.apps_rounded,
            color: AppColors.primary, size: 21),
      );
}

class _UsageDistribution extends StatelessWidget {
  const _UsageDistribution({required this.apps});
  final List<ManagedApp> apps;

  @override
  Widget build(BuildContext context) {
    final used = apps.where((app) => app.usageBytes > 0).toList()
      ..sort((a, b) => b.usageBytes.compareTo(a.usageBytes));
    if (used.isEmpty) {
      return const _EmptyCard(
          message: 'سيظهر التوزيع بعد قراءة استهلاك التطبيقات من Android.');
    }
    final shown = used.take(5).toList();
    final total = shown.fold<int>(0, (sum, app) => sum + app.usageBytes);
    final colors = [
      AppColors.primary,
      AppColors.teal,
      AppColors.cyan,
      AppColors.warning,
      AppColors.danger
    ];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              SizedBox(
                  width: 132,
                  height: 132,
                  child: PieChart(PieChartData(
                      centerSpaceRadius: 37,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < shown.length; i++)
                          PieChartSectionData(
                              value: shown[i].usageBytes.toDouble(),
                              color: colors[i],
                              radius: 22,
                              showTitle: false)
                      ]))),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    for (var i = 0; i < shown.length; i++)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LegendItem(
                              color: colors[i],
                              label: shown[i].name,
                              value:
                                  '${(shown[i].usageBytes / total * 100).toStringAsFixed(0)}%'))
                  ]))
            ])));
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700))),
        Text(value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))
      ]);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.hourglass_empty_rounded, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.4)))
          ])));
}
