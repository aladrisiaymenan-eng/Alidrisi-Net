import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/branding/app_brand.dart';
import 'core/native/native_connector.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ui.dart';
import 'data/models/app_models.dart';
import 'providers/app_state.dart';
import 'screens/about_developer_screen.dart';
import 'screens/apps_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';

void main() => runApp(const ProviderScope(child: InternetManagerApp()));

class InternetManagerApp extends ConsumerWidget {
  const InternetManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(appStateProvider.select((state) => state.themeMode));
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink()),
      home: const AppEntry(),
    );
  }
}

class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry>
    with WidgetsBindingObserver {
  bool _permissionSheetScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final state = ref.read(appStateProvider);
    if (lifecycleState == AppLifecycleState.resumed && mounted) {
      state.setAppForeground(true);
      state.refreshDeviceData(force: true);
    } else if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      state.setAppForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    if (!state.initialized) return const _BrandSplash();
    if (!state.onboardingDone) return const OnboardingScreen();
    if (!_permissionSheetScheduled && !state.permissionPromptShown) {
      _permissionSheetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(appStateProvider).permissionPromptShown) {
          _showPermissionCenter();
        }
      });
    }
    return const AppShell();
  }

  Future<void> _prepareAllPermissions(BuildContext sheetContext) async {
    final notification = await NativeConnector.requestNotificationPermission();
    if (!mounted) return;
    if (notification == 'GRANTED') {
      final appState = ref.read(appStateProvider);
      await appState.refreshDeviceData();
      await appState.startSpeedService();
    }
    final vpn = await NativeConnector.requestVpnPermission();
    if (!mounted) return;
    if (vpn == 'GRANTED') {
      await ref.read(appStateProvider).refreshDeviceData();
    }
    if (!mounted) return;
    await ref.read(appStateProvider).openUsageAccessSettings();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  Future<void> _showPermissionCenter() async {
    final state = ref.read(appStateProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تجهيز التطبيق',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                  'لن يمنح الأدريسي أي صلاحية بصمت. اختر ما تحتاجه فقط، ويمكنك تخطي الخطوة والعودة إليها من الإعدادات.',
                  style: TextStyle(color: AppColors.muted, height: 1.45)),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    state.usageAccessGranted
                        ? Icons.check_circle_rounded
                        : Icons.query_stats_rounded,
                    color: state.usageAccessGranted
                        ? AppColors.success
                        : AppColors.primary),
                title: const Text('بيانات الاستخدام',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(state.usageAccessGranted
                    ? 'مفعلة — يمكن قراءة استهلاك التطبيقات'
                    : 'مطلوبة لعرض استهلاك كل تطبيق'),
                trailing: state.usageAccessGranted
                    ? null
                    : TextButton(
                        onPressed: () async {
                          await state.openUsageAccessSettings();
                          await Future<void>.delayed(
                              const Duration(milliseconds: 300));
                          await ref.read(appStateProvider).refreshDeviceData();
                          if (sheetContext.mounted) setState(() {});
                        },
                        child: const Text('فتح')),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    state.notificationsGranted
                        ? Icons.check_circle_rounded
                        : Icons.notifications_active_outlined,
                    color: state.notificationsGranted
                        ? AppColors.success
                        : AppColors.warning),
                title: const Text('إشعارات العداد والحدود',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(state.notificationsGranted
                    ? 'مفعلة — يمكن تشغيل الخدمات الخلفية'
                    : 'مطلوبة فقط عند تشغيل العداد أو مراقبة الحدود'),
                trailing: state.notificationsGranted
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final result = await NativeConnector
                              .requestNotificationPermission();
                          if (sheetContext.mounted) setState(() {});
                          if (result == 'GRANTED') {
                            await ref
                                .read(appStateProvider)
                                .refreshDeviceData();
                          }
                          if (sheetContext.mounted) setState(() {});
                        },
                        child: const Text('طلب')),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    state.vpnPrepared
                        ? Icons.check_circle_rounded
                        : Icons.vpn_key_outlined,
                    color: state.vpnPrepared
                        ? AppColors.success
                        : AppColors.warning),
                title: const Text('موافقة حجب التطبيقات VPN',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(state.vpnPrepared
                    ? 'مفعلة — يمكن تطبيق الحظر الانتقائي'
                    : 'مطلوبة عند أول حظر أو حد يتجاوز الاستهلاك'),
                trailing: state.vpnPrepared
                    ? null
                    : TextButton(
                        onPressed: () async {
                          await NativeConnector.requestVpnPermission();
                          await ref.read(appStateProvider).refreshDeviceData();
                          if (sheetContext.mounted) setState(() {});
                        },
                        child: const Text('طلب')),
              ),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () => _prepareAllPermissions(sheetContext),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('تجهيز الصلاحيات المطلوبة'))),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('متابعة لاحقًا'))),
            ],
          ),
        ),
      ),
    );
    if (mounted) await ref.read(appStateProvider).markPermissionPromptShown();
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(color: Color(0xFF0C2940)),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset(AppBrand.iconAsset, width: 96, height: 96),
              const SizedBox(height: 20),
              const Text(AppBrand.shortName,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(AppBrand.tagline,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .74),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: Colors.white.withValues(alpha: .18),
                      color: Colors.white)),
            ]),
          ),
        ),
      );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const screens = [
    DashboardScreen(),
    AppsScreen(),
    StatsScreen(),
    RulesScreen(),
    SettingsScreen()
  ];
  static const destinations = [
    NavigationDestination(
        icon: Icon(Icons.grid_view_rounded),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'الرئيسية'),
    NavigationDestination(
        icon: Icon(Icons.apps_rounded),
        selectedIcon: Icon(Icons.apps_rounded),
        label: 'التطبيقات'),
    NavigationDestination(
        icon: Icon(Icons.insights_rounded),
        selectedIcon: Icon(Icons.insights_rounded),
        label: 'الإحصائيات'),
    NavigationDestination(
        icon: Icon(Icons.rule_folder_outlined),
        selectedIcon: Icon(Icons.rule_folder_rounded),
        label: 'الأتمتة'),
    NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return Scaffold(
      body: Column(
        children: [
          if (state.speedMeterInAppBar) _SpeedStatusBar(state: state),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              child: AnimatedEntrance(
                  key: ValueKey(state.selectedTab),
                  child: IndexedStack(
                      index: state.selectedTab, children: screens)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
          selectedIndex: state.selectedTab,
          onDestinationSelected: ref.read(appStateProvider).setTab,
          destinations: destinations),
    );
  }
}

class _SpeedStatusBar extends StatelessWidget {
  const _SpeedStatusBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.speedServiceEnabled;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.teal.withValues(alpha: .10)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active
                    ? AppColors.teal.withValues(alpha: .28)
                    : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(active ? Icons.speed_rounded : Icons.speed_outlined,
                  size: 18, color: active ? AppColors.teal : AppColors.muted),
              const SizedBox(width: 8),
              Text(active ? 'السرعة المباشرة' : 'عداد السرعة متوقف',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(state.networkType,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted))),
              Text('↓ ${formatRate(state.downloadKbps)}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('↑ ${formatRate(state.uploadKbps)}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// نقطة تنقل صغيرة تستخدمها شاشة الإعدادات دون خلطها مع التبويبات الأساسية.
void openAboutDeveloper(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const AboutDeveloperScreen()));
