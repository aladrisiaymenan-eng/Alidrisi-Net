import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import '../data/models/app_models.dart';
import '../providers/app_state.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    const filters = [
      'الكل',
      'المفضلة',
      'محظورة',
      'Wi-Fi فقط',
      'بيانات الجوال',
      'تحتاج انتباه'
    ];
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('التطبيقات والشبكة',
                              style: TextStyle(
                                  fontSize: 25, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('استهلاك اليوم لكل تطبيق — يتجدد تلقائيًا',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: () => _showSort(context, ref),
                        tooltip: 'ترتيب',
                        icon: const Icon(Icons.swap_vert_rounded)),
                    IconButton(
                        onPressed: () => _showHelp(context),
                        tooltip: 'مساعدة',
                        icon: const Icon(Icons.help_outline_rounded)),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  onChanged: ref.read(appStateProvider).setQuery,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                      hintText: 'ابحث باسم التطبيق أو الحزمة',
                      prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final filter in filters)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: state.appFilter == filter,
                            onSelected: (_) =>
                                ref.read(appStateProvider).setFilter(filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('${state.filteredApps.length} تطبيق ظاهر',
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Pill(
                      label: state.isVpnActive
                          ? 'حظر VPN فعال'
                          : 'الحظر يحتاج VPN',
                      color: state.isVpnActive
                          ? AppColors.teal
                          : AppColors.warning,
                      icon: state.isVpnActive
                          ? Icons.security_rounded
                          : Icons.info_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.dataError != null)
                  _InfoCard(message: state.dataError!),
                if (!state.nativeSupported)
                  const _InfoCard(
                      message:
                          'اكتشاف التطبيقات واستهلاكها الحقيقي متاح على Android فقط.'),
                if (state.nativeSupported && !state.usageAccessGranted)
                  const _InfoCard(
                      message:
                          'التطبيقات ظهرت من الجهاز. فعّل إذن الوصول إلى بيانات الاستخدام لرؤية الاستهلاك حسب UID.'),
                if (state.nativeSupported &&
                    state.usageAccessGranted &&
                    state.limitMonitorRunning)
                  const _InfoCard(
                      message:
                          'مراقبة الحدود تعمل في الخلفية وتراجع الحصص دوريًا. قد يتأخر الحظر حتى دورة الفحص التالية.'),
                const SizedBox(height: 10),
                if (state.filteredApps.isEmpty &&
                    (state.isRefreshing || state.lastRefresh == null))
                  const _AppsLoadingState()
                else if (state.filteredApps.isEmpty)
                  const SizedBox(
                      height: 280,
                      child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'لا توجد نتائج مطابقة',
                          subtitle: 'جرّب كلمة بحث مختلفة أو اختر فلترًا آخر')),
                ...state.filteredApps.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AppListCard(
                        app: app,
                        onTap: () => _showAppDetails(context, ref, app)))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showSort(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _SortSheet(
          current: ref.read(appStateProvider).appSort,
          onSelected: (value) {
            ref.read(appStateProvider).setSort(value);
            Navigator.pop(context);
          },
        ),
      );

  void _showHelp(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('نظام التحكم بالشبكة'),
          content: const Text(
              'الحظر الكامل يمر عبر خدمة VPN بعد منح الإذن. حدود الاستهلاك تُراجع دوريًا في خدمة خلفية عندما تكون Usage Access والإشعارات متاحة. أما وضع Wi‑Fi فقط وبيانات الجوال فقط فيُحفظ كسياسة لأن Android لا يتيح فرض توجيهها للتطبيقات العامة بطريقة مضمونة.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'))
          ],
        ),
      );

  void _showAppDetails(BuildContext context, WidgetRef ref, ManagedApp app) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _AppDetails(app: app),
      );
}

class _AppsLoadingState extends StatelessWidget {
  const _AppsLoadingState();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .045),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            const Text('جاري قراءة التطبيقات من الهاتف',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                'ستظهر البيانات السابقة فورًا، ثم تُحدّث القراءة الحقيقية تلقائيًا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4)),
          ]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.warning.withValues(alpha: .08),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(fontSize: 12, height: 1.4))),
            ],
          ),
        ),
      );
}

class _AppListCard extends StatelessWidget {
  const _AppListCard({required this.app, required this.onTap});
  final ManagedApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final modeColor = app.accessMode == AccessMode.blocked
        ? AppColors.danger
        : app.accessMode == AccessMode.wifiOnly
            ? AppColors.warning
            : AppColors.success;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  _BrandAppIcon(app: app, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                                child: Text(app.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15))),
                            if (app.isFavorite)
                              const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(Icons.star_rounded,
                                      color: Colors.orange, size: 15)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(app.packageName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatBytes(app.usageBytes),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      const Text('اليوم',
                          style:
                              TextStyle(fontSize: 9, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
              if (app.autoBlocked) ...[
                const SizedBox(height: 8),
                const Align(
                    alignment: Alignment.centerRight,
                    child: Text('حُجب تلقائيًا بعد تجاوز الحد',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 9),
              Row(
                children: [
                  Pill(
                      label: accessModeLabel(app.accessMode),
                      color: modeColor,
                      icon: app.isBlocked
                          ? Icons.block_rounded
                          : Icons.network_check_rounded),
                  const Spacer(),
                  Text('Wi‑Fi ${formatBytes(app.wifiBytes)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted)),
                  const SizedBox(width: 9),
                  Text('جوال ${formatBytes(app.mobileBytes)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandAppIcon extends StatelessWidget {
  const _BrandAppIcon({required this.app, required this.size});
  final ManagedApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (app.iconBytes != null) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.memory(app.iconBytes!,
              width: size, height: size, fit: BoxFit.cover));
    }
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(size * .28)),
        child: Icon(Icons.apps_rounded,
            color: AppColors.primary, size: size * .52));
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.onSelected});
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ترتيب التطبيقات',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            for (final item in const {
              'الاستهلاك': 'الأكثر استهلاكًا',
              'الاسم': 'الاسم: أ ـ ي',
              'الحالة': 'الحالة',
              'المفضلة أولًا': 'المفضلة أولًا'
            }.entries)
              ListTile(
                leading: Icon(
                    item.key == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.key == current
                        ? AppColors.primary
                        : AppColors.muted),
                title: Text(item.value),
                onTap: () => onSelected(item.key),
              ),
          ],
        ),
      );
}

class _AppDetails extends ConsumerWidget {
  const _AppDetails({required this.app});
  final ManagedApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final currentApp =
        state.apps.firstWhere((item) => item.id == app.id, orElse: () => app);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _BrandAppIcon(app: currentApp, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentApp.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(currentApp.packageName,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () =>
                      ref.read(appStateProvider).toggleFavorite(currentApp.id),
                  icon: Icon(
                      currentApp.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.orange,
                      size: 28)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerRight,
              child: Text(
                  'UID: ${currentApp.uid ?? 'غير متاح'}  •  ${currentApp.isSystemApp ? 'تطبيق نظام' : 'تطبيق مستخدم'}  •  صلاحيات ممنوحة ${currentApp.grantedPermissions.length}/${currentApp.requestedPermissions.length}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 10))),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                      child: _UsageValue(
                          icon: Icons.data_usage_rounded,
                          label: 'الإجمالي',
                          value: formatBytes(currentApp.usageBytes),
                          color: AppColors.primary)),
                  Container(height: 30, width: 1, color: AppColors.border),
                  Expanded(
                      child: _UsageValue(
                          icon: Icons.wifi_rounded,
                          label: 'Wi‑Fi',
                          value: formatBytes(currentApp.wifiBytes),
                          color: AppColors.primary)),
                  Container(height: 30, width: 1, color: AppColors.border),
                  Expanded(
                      child: _UsageValue(
                          icon: Icons.phone_android_rounded,
                          label: 'الجوال',
                          value: formatBytes(currentApp.mobileBytes),
                          color: AppColors.teal)),
                ],
              ),
            ),
          ),
          if (currentApp.autoBlocked) ...[
            const SizedBox(height: 8),
            const Align(
                alignment: Alignment.centerRight,
                child: Text('تم تفعيل الحظر تلقائيًا لأن الاستهلاك تجاوز الحد.',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ],
          const SizedBox(height: 18),
          const Align(
              alignment: Alignment.centerRight,
              child: Text('سياسة الشبكة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          const SizedBox(height: 6),
          RadioGroup<AccessMode>(
            groupValue: currentApp.accessMode,
            onChanged: (value) async {
              if (value == null) return;
              final result = await ref
                  .read(appStateProvider)
                  .updateMode(currentApp.id, value);
              if (context.mounted && result.startsWith('ERROR')) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر تطبيق السياسة: $result')));
              }
            },
            child: Column(
              children: [
                for (final mode in AccessMode.values)
                  RadioListTile<AccessMode>(
                    value: mode,
                    contentPadding: EdgeInsets.zero,
                    title: Text(accessModeLabel(mode),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    secondary: Icon(
                        mode == AccessMode.blocked
                            ? Icons.block_rounded
                            : mode == AccessMode.wifiOnly
                                ? Icons.wifi_rounded
                                : Icons.network_check_rounded,
                        color: mode == AccessMode.blocked
                            ? AppColors.danger
                            : AppColors.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                  child: Text('حد الاستهلاك',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14))),
              Text(
                  currentApp.limitBytes > 0
                      ? formatBytes(currentApp.limitBytes)
                      : 'بدون حد',
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final limit in const {
                'بدون حد': 0,
                '500 م.ب': 500 * 1024 * 1024,
                '1 ج.ب': 1024 * 1024 * 1024,
                '2 ج.ب': 2 * 1024 * 1024 * 1024
              }.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: () =>
                          _saveLimit(context, ref, currentApp, limit.value),
                      child: Text(limit.key,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentApp.limitBytes > 0
                    ? () => _saveLimit(context, ref, currentApp, 0)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 17),
                label: const Text('إلغاء الحد'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCustomLimit(context, ref, currentApp),
                icon: const Icon(Icons.edit_rounded, size: 17),
                label: const Text('حد مخصص'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'))),
        ],
      ),
    );
  }

  Future<void> _saveLimit(
      BuildContext context, WidgetRef ref, ManagedApp app, int limit) async {
    final result = await ref.read(appStateProvider).updateLimit(app.id, limit);
    if (!context.mounted) return;
    if (result.startsWith('ERROR')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم حفظ الحد، لكن تعذر تفعيل الحظر: $result')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(limit == 0
              ? 'تم إلغاء حد التطبيق مع إبقاء سياسة الحظر اليدوي كما هي'
              : 'تم حفظ الحد ومزامنة المراقبة')));
    }
  }

  Future<void> _showCustomLimit(
      BuildContext context, WidgetRef ref, ManagedApp app) async {
    final controller = TextEditingController(
        text: app.limitBytes > 0
            ? (app.limitBytes / (1024 * 1024)).round().toString()
            : '');
    final limitMb = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حد مخصص'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'الحد بالميجابايت',
              hintText: 'مثال: 750 — اكتب 0 لإلغاء الحد'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (limitMb == null || !context.mounted) return;
    await _saveLimit(context, ref, app, limitMb * 1024 * 1024);
  }
}

class _UsageValue extends StatelessWidget {
  const _UsageValue(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      );
}
