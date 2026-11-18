import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/app_brand.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/ui.dart';
import '../providers/app_state.dart';
import 'about_developer_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
        children: [
          const Text('الإعدادات',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('تحكم في الصلاحيات والخدمات والبيانات المحفوظة.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Image.asset(AppBrand.iconAsset, width: 54, height: 54),
                  const SizedBox(width: 13),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(AppBrand.shortName,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('بيانات الجهاز تبقى محلية ولا تُرسل إلى خادم.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11))
                      ])),
                  const Icon(Icons.lock_outline_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'الصلاحيات وحالة الجهاز'),
          const SizedBox(height: 10),
          _PermissionCard(state: state),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.query_stats_rounded,
              color: AppColors.primary,
              title: 'إذن بيانات الاستخدام',
              subtitle: state.usageAccessGranted
                  ? 'ممنوح — يمكن قراءة الاستهلاك حسب التطبيق'
                  : 'مطلوب لقراءة الاستهلاك الحقيقي حسب UID',
              onTap: () => state.openUsageAccessSettings()),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.vpn_key_rounded,
              color: state.vpnPrepared ? AppColors.success : AppColors.warning,
              title: 'موافقة VPN للحجب',
              subtitle: state.vpnPrepared
                  ? 'مفعلة — يمكن حجب التطبيقات المحددة'
                  : 'مطلوبة لتطبيق الحظر اليدوي والتلقائي',
              onTap: () => _requestVpnPermission(context, state)),
          const SizedBox(height: 24),
          const SectionTitle(title: 'الخدمات والتفضيلات'),
          const SizedBox(height: 10),
          _SettingTile(
              icon: Icons.shield_outlined,
              color: state.isVpnActive ? AppColors.teal : AppColors.warning,
              title: 'حظر التطبيقات عبر VPN',
              subtitle: state.isVpnActive
                  ? 'الخدمة فعالة للتطبيقات المحظورة'
                  : 'تحتاج اختيار تطبيق محظور ومنح إذن VPN',
              trailing: Switch.adaptive(
                  value: state.isVpnActive,
                  activeTrackColor: AppColors.teal,
                  onChanged: (_) => _toggleVpnService(context, state))),
          const SizedBox(height: 8),
          _SettingTile(
              icon: Icons.dark_mode_rounded,
              color: AppColors.primary,
              title: 'المظهر',
              subtitle: state.themeMode == ThemeMode.dark
                  ? 'الوضع الداكن'
                  : 'الوضع الفاتح',
              trailing: Switch.adaptive(
                  value: state.themeMode == ThemeMode.dark,
                  activeTrackColor: AppColors.primary,
                  onChanged: (_) => ref.read(appStateProvider).toggleTheme())),
          const SizedBox(height: 8),
          _SettingTile(
              icon: Icons.notifications_active_rounded,
              color: AppColors.teal,
              title: 'الإشعارات الذكية',
              subtitle: state.notificationsEnabled
                  ? 'تنبيه عند تجاوز حد تطبيق'
                  : 'تنبيهات الحدود متوقفة',
              trailing: Switch.adaptive(
                  value: state.notificationsEnabled,
                  activeTrackColor: AppColors.teal,
                  onChanged: (_) =>
                      ref.read(appStateProvider).toggleNotifications())),
          const SizedBox(height: 8),
          _SettingTile(
              icon: Icons.speed_rounded,
              color: AppColors.warning,
              title: 'عداد السرعة داخل التطبيق',
              subtitle: state.speedMeterInAppBar
                  ? 'تنزيل ورفع واستخدام اليوم في أعلى الشاشة'
                  : 'متوقف',
              trailing: Switch.adaptive(
                  value: state.speedMeterInAppBar,
                  activeTrackColor: AppColors.warning,
                  onChanged: (_) =>
                      ref.read(appStateProvider).toggleSpeedMeterAppBar())),
          const SizedBox(height: 8),
          _SettingTile(
              icon: Icons.notifications_none_rounded,
              color: AppColors.primary,
              title: 'عداد السرعة في الخلفية',
              subtitle: state.speedServiceEnabled
                  ? 'إشعار دائم بالسرعة واستخدام اليوم'
                  : 'متوقف لتوفير البطارية',
              trailing: Switch.adaptive(
                  value: state.speedServiceEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (_) => _toggleSpeedService(context, state))),
          const SizedBox(height: 8),
          _SettingTile(
              icon: Icons.data_saver_on_rounded,
              color: state.limitMonitorRunning
                  ? AppColors.teal
                  : AppColors.warning,
              title: 'مراقبة حدود التطبيقات',
              subtitle: state.limitMonitorRunning
                  ? 'يفحص الحصص ويطبّق الحظر تلقائيًا'
                  : state.usageAccessGranted
                      ? 'تعمل عند تعيين حد لتطبيق'
                      : 'تحتاج Usage Access وإذن الإشعارات',
              trailing: Switch.adaptive(
                  value: state.limitMonitoringEnabled,
                  activeTrackColor: AppColors.teal,
                  onChanged: (_) =>
                      ref.read(appStateProvider).toggleLimitMonitor())),
          const SizedBox(height: 24),
          const SectionTitle(title: 'البيانات والنسخ الاحتياطي'),
          const SizedBox(height: 10),
          _ActionTile(
              icon: Icons.cloud_download_rounded,
              color: AppColors.teal,
              title: 'تصدير نسخة احتياطية',
              subtitle: 'الإعدادات والسياسات والقواعد كاملة بصيغة JSON',
              onTap: () => _export(context, state)),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.restore_rounded,
              color: AppColors.primary,
              title: 'استيراد نسخة احتياطية',
              subtitle: 'تحقق من ملف JSON وطبّق سياساته على التطبيقات الحالية',
              onTap: () => _import(context, state)),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.delete_sweep_rounded,
              color: AppColors.danger,
              title: 'إعادة تعيين فترة القياس',
              subtitle:
                  'يبدأ القياس من الآن دون حذف إحصائيات Android التاريخية',
              onTap: () => _confirmReset(context, ref)),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.gpp_bad_outlined,
              color: AppColors.warning,
              title: 'إعادة تعيين القيود',
              subtitle:
                  'إلغاء الحظر والحدود لكل التطبيقات مع إبقاء إحصائيات Android',
              onTap: () => _confirmResetPolicies(context, ref)),
          const SizedBox(height: 8),
          _ActionTile(
              icon: Icons.rule_folder_outlined,
              color: AppColors.primary,
              title: 'إعادة تعيين القواعد',
              subtitle: 'استعادة القواعد الافتراضية وحذف القواعد المخصصة',
              onTap: () => _confirmResetRules(context, ref)),
          const SizedBox(height: 24),
          const SectionTitle(title: 'عن التطبيق'),
          const SizedBox(height: 10),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AboutDeveloperScreen())),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.person_outline_rounded,
                          color: AppColors.primary)),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('عن المطور',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        SizedBox(height: 4),
                        Text(AppBrand.developerName,
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 12))
                      ])),
                  const Icon(Icons.chevron_left_rounded,
                      color: AppColors.muted),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Image.asset(AppBrand.iconAsset, width: 48, height: 48),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(AppBrand.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('الإصدار 1.0.0 • Android',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11)),
                      SizedBox(height: 6),
                      Text(AppBrand.tagline,
                          style: TextStyle(
                              color: AppColors.teal,
                              fontSize: 12,
                              fontWeight: FontWeight.w700))
                    ]))
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVpnService(BuildContext context, AppState state) async {
    final result = await state.toggleVpn();
    if (!context.mounted || result == 'STARTED' || result == 'STOPPED') return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result == 'NO_BLOCKED_APPS'
            ? 'اختر تطبيقًا بحالة حظر أولًا'
            : 'تعذر تطبيق VPN: $result')));
  }

  Future<void> _requestVpnPermission(
      BuildContext context, AppState state) async {
    final result = await state.requestVpnPermission();
    if (!context.mounted || result == 'GRANTED') return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('لم تتم موافقة VPN: $result')));
  }

  Future<void> _toggleSpeedService(BuildContext context, AppState state) async {
    final result = state.speedServiceEnabled
        ? await state.stopSpeedService()
        : await state.startSpeedService();
    if (!context.mounted || result == 'STARTED' || result == 'STOPPED') return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل عداد الخلفية: $result')));
  }

  Future<void> _export(BuildContext context, AppState state) async {
    final backup = jsonEncode(state.backupData());
    final result = await FilePicker.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: 'internet_manager_backup.json',
        bytes: Uint8List.fromList(utf8.encode(backup)),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: ['json']);
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير النسخة الاحتياطية الكاملة')));
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final files = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      final applied = decoded is Map<String, dynamic> &&
          await state.importBackupData(decoded);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(applied
                ? 'تم التحقق من النسخة وتطبيق السياسات'
                : 'ملف النسخة غير صالح')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر قراءة ملف JSON')));
      }
    }
  }

  void _confirmReset(BuildContext context, WidgetRef ref) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
              title: const Text('إعادة تعيين فترة القياس؟'),
              content: const Text(
                  'سيبدأ التطبيق قراءة جديدة من الآن، ولن يحذف بيانات Android التاريخية من النظام.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () async {
                      await ref.read(appStateProvider).resetStats();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('بدأت فترة قياس جديدة')));
                      }
                    },
                    child: const Text('إعادة التعيين'))
              ]));

  void _confirmResetPolicies(BuildContext context, WidgetRef ref) => showDialog<
          void>(
      context: context,
      builder: (_) => AlertDialog(
              title: const Text('إعادة تعيين القيود؟'),
              content: const Text(
                  'سيتم إلغاء الحظر اليدوي والتلقائي وحذف حدود التطبيقات، مع عدم حذف سجل Android التاريخي.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () async {
                      await ref.read(appStateProvider).resetPolicies();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تمت إعادة تعيين القيود')));
                      }
                    },
                    child: const Text('إعادة التعيين'))
              ]));

  void _confirmResetRules(BuildContext context, WidgetRef ref) => showDialog<
          void>(
      context: context,
      builder: (_) => AlertDialog(
              title: const Text('إعادة تعيين القواعد؟'),
              content: const Text(
                  'ستعود القواعد الافتراضية وتُحذف القواعد المخصصة. لا يتغير سجل الاستهلاك.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () async {
                      await ref.read(appStateProvider).resetRules();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تمت إعادة تعيين القواعد')));
                      }
                    },
                    child: const Text('إعادة التعيين'))
              ]));
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _PermissionRow(
                label: 'Android مدعوم', value: state.nativeSupported),
            _PermissionRow(
                label: 'بيانات الاستخدام', value: state.usageAccessGranted),
            _PermissionRow(
                label: 'إذن الإشعارات', value: state.notificationsGranted),
            _PermissionRow(label: 'موافقة VPN', value: state.vpnPrepared),
            _PermissionRow(
                label: 'بيانات التطبيقات', value: state.apps.isNotEmpty),
            if (state.dataError != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(state.dataError!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 11, height: 1.35)),
              ),
            ],
          ])));
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.value});
  final String label;
  final bool value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(
            value
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: value ? AppColors.success : AppColors.muted),
        const SizedBox(width: 9),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
        Text(value ? 'جاهز' : 'غير جاهز',
            style: const TextStyle(color: AppColors.muted, fontSize: 11))
      ]));
}

class _SettingTile extends StatelessWidget {
  const _SettingTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.trailing});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted))
                ])),
            trailing
          ])));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon, color: color, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              height: 1.3))
                    ])),
                const Icon(Icons.chevron_left_rounded, color: AppColors.muted)
              ]))));
}
