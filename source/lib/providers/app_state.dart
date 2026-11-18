import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/native/native_connector.dart';
import '../core/theme/app_theme.dart';
import '../data/models/app_models.dart';
import '../data/policy_engine.dart';

final appStateProvider =
    ChangeNotifierProvider<AppState>((ref) => AppState()..init());

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  int selectedTab =
      int.tryParse(Uri.base.queryParameters['tab'] ?? '0')?.clamp(0, 4) ?? 0;
  bool isVpnActive = false;
  bool notificationsEnabled = true;
  bool speedMeterInAppBar = true;
  bool speedServiceEnabled = false;
  bool limitMonitorRunning = false;
  bool limitMonitoringEnabled = true;
  bool onboardingDone = false;
  bool permissionPromptShown = false;
  bool initialized = false;
  bool isRefreshing = false;
  bool usageAccessGranted = false;
  bool notificationsGranted = false;
  bool vpnPrepared = false;
  bool nativeSupported = false;
  String? dataError;
  String networkType = 'غير متصل';
  String query = '';
  String appFilter = 'الكل';
  String appSort = 'الاستهلاك';
  int selectedPeriod = 0;
  double downloadKbps = 0;
  double uploadKbps = 0;
  double peakDownloadKbps = 0;
  int dailyWifiUsageBytes = 0;
  int dailyMobileUsageBytes = 0;
  final List<double> downloadHistory = <double>[];
  DateTime usageStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime? todayResetAt;
  int _todayBaselineMobileBytes = 0;
  int _todayBaselineWifiBytes = 0;
  Map<String, int> _todayBaselineApps = <String, int>{};
  Map<String, int> _todayBaselineAppWifi = <String, int>{};
  Map<String, int> _todayBaselineAppMobile = <String, int>{};
  final Map<String, Map<String, dynamic>> _dayBaselines =
      <String, Map<String, dynamic>>{};
  DateTime? lastRefresh;
  DateTime? _lastDeviceRefreshAttemptAt;

  List<ManagedApp> apps = <ManagedApp>[];
  List<DailyUsageRecord> dailyRecords = <DailyUsageRecord>[];
  DataPlan? plan;
  List<SmartRule> rules = const [
    SmartRule(
      id: 'limit',
      title: 'إشعار عند تجاوز حد التطبيق',
      description: 'يراقب الاستهلاك الحقيقي ويبلغك عند وصول التطبيق إلى الحد.',
      icon: Icons.data_usage_rounded,
      enabled: true,
      color: AppColors.indigo,
    ),
    SmartRule(
      id: 'battery',
      title: 'توفير البطارية والبيانات',
      description: 'يعرض التطبيقات ذات الاستهلاك الأعلى لتتخذ قرارًا واضحًا.',
      icon: Icons.battery_saver_rounded,
      enabled: true,
      color: AppColors.teal,
    ),
    SmartRule(
      id: 'study',
      title: 'وقت التركيز والدراسة',
      description: 'يطبّق سياسة التطبيقات التي تختارها أثناء الوقت المحدد.',
      icon: Icons.school_rounded,
      enabled: false,
      color: Colors.orange,
    ),
  ];
  List<AppProfile> profiles = const [
    AppProfile(
      id: 'study',
      name: 'الدراسة والتركيز',
      description: 'حظر التطبيقات التي تحددها أثناء وقت التركيز.',
      icon: Icons.school_rounded,
      color: AppColors.indigo,
      active: false,
      appCount: 0,
    ),
    AppProfile(
      id: 'work',
      name: 'العمل والإنتاجية',
      description: 'السماح بالتطبيقات الضرورية وحظر مصادر التشتيت.',
      icon: Icons.work_rounded,
      color: AppColors.teal,
      active: false,
      appCount: 0,
    ),
    AppProfile(
      id: 'saver',
      name: 'التوفير',
      description: 'اقتراح تقييد التطبيقات الأعلى استهلاكًا إلى Wi‑Fi فقط.',
      icon: Icons.eco_rounded,
      color: Colors.orange,
      active: false,
      appCount: 0,
    ),
  ];

  Timer? _refreshTimer;
  Timer? _deviceRefreshTimer;
  Timer? _currentUsageTimer;
  SharedPreferences? _prefs;
  bool _currentUsageRefreshing = false;
  bool _serviceRecoveryInFlight = false;
  bool _appInForeground = true;

  List<ManagedApp> get filteredApps {
    final normalizedQuery = query.trim().toLowerCase();
    final result = apps.where((app) {
      final matchesQuery = normalizedQuery.isEmpty ||
          app.name.toLowerCase().contains(normalizedQuery) ||
          app.packageName.toLowerCase().contains(normalizedQuery);
      final matchesFilter = appFilter == 'الكل' ||
          (appFilter == 'المفضلة' && app.isFavorite) ||
          (appFilter == 'محظورة' && app.accessMode == AccessMode.blocked) ||
          (appFilter == 'Wi-Fi فقط' && app.accessMode == AccessMode.wifiOnly) ||
          (appFilter == 'بيانات الجوال' &&
              app.accessMode == AccessMode.mobileOnly) ||
          (appFilter == 'تحتاج انتباه' && app.nearLimit);
      return matchesQuery && matchesFilter;
    }).toList();
    result.sort((a, b) {
      if (appSort == 'الاسم') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (appSort == 'الحالة') {
        return accessModeLabel(a.accessMode)
            .compareTo(accessModeLabel(b.accessMode));
      }
      if (appSort == 'المفضلة أولًا') {
        return (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
      }
      return b.usageBytes.compareTo(a.usageBytes);
    });
    return result;
  }

  int get todayAppsUsage =>
      apps.fold(0, (total, app) => total + app.usageBytes);
  int get totalUsage => todayAppsUsage;
  int get totalWifiUsage => apps.fold(0, (total, app) => total + app.wifiBytes);
  int get totalMobileUsage =>
      apps.fold(0, (total, app) => total + app.mobileBytes);
  DailyUsageRecord? get todayRecord {
    final label = _dateLabel(DateTime.now().millisecondsSinceEpoch);
    for (final record in dailyRecords) {
      if (record.dateLabel == label) return record;
    }
    return null;
  }

  int get todayWifiUsage => todayRecord?.wifiBytes ?? dailyWifiUsageBytes;
  int get todayMobileUsage => todayRecord?.mobileBytes ?? dailyMobileUsageBytes;
  int get todayTotalUsage => todayWifiUsage + todayMobileUsage;
  int get blockedCount =>
      apps.where((app) => app.accessMode == AccessMode.blocked).length;
  int get selectedPeriodDays => selectedPeriod == 0
      ? 1
      : selectedPeriod == 1
          ? 7
          : 30;
  String get selectedPeriodLabel => selectedPeriod == 0
      ? 'اليوم'
      : selectedPeriod == 1
          ? 'آخر 7 أيام'
          : 'آخر 30 يومًا';
  List<DailyUsageRecord> get selectedPeriodRecords {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final start = todayStart.subtract(Duration(days: selectedPeriodDays - 1));
    return dailyRecords.where((record) {
      final day = _recordDay(record);
      return !day.isBefore(start) && !day.isAfter(todayStart);
    }).toList();
  }

  int get selectedPeriodTotalUsage => selectedPeriodRecords.fold<int>(
      0, (sum, record) => sum + record.totalBytes);
  int get selectedPeriodWifiUsage => selectedPeriodRecords.fold<int>(
      0, (sum, record) => sum + record.wifiBytes);
  int get selectedPeriodMobileUsage => selectedPeriodRecords.fold<int>(
      0, (sum, record) => sum + record.mobileBytes);
  double get selectedPeriodAverage =>
      selectedPeriodTotalUsage / selectedPeriodDays;
  List<DailyUsageRecord> get chartRecords {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final start = todayStart.subtract(Duration(days: selectedPeriodDays - 1));
    final byDay = <String, DailyUsageRecord>{
      for (final record in selectedPeriodRecords) record.dateLabel: record,
    };
    return List<DailyUsageRecord>.generate(selectedPeriodDays, (index) {
      final day = start.add(Duration(days: index));
      final label = _dateLabel(day.millisecondsSinceEpoch);
      return byDay[label] ??
          DailyUsageRecord(
              dateLabel: label,
              dayStartMillis: day.millisecondsSinceEpoch,
              mobileBytes: 0,
              wifiBytes: 0);
    });
  }

  int get downloadSpeed => downloadKbps.round();
  int get uploadSpeed => uploadKbps.round();
  int get peakSpeed => peakDownloadKbps.round();
  bool get hasRealData =>
      nativeSupported && usageAccessGranted && apps.isNotEmpty;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final prefs = _prefs!;
      onboardingDone = prefs.getBool('onboarding_done') ?? false;
      permissionPromptShown = prefs.getBool('permission_prompt_shown') ?? false;
      notificationsEnabled = prefs.getBool('notifications') ?? true;
      speedMeterInAppBar = prefs.getBool('speed_meter_appbar') ?? true;
      speedServiceEnabled = prefs.getBool('speed_service_enabled') ?? false;
      limitMonitoringEnabled =
          prefs.getBool('limit_monitor_user_enabled') ?? true;
      themeMode =
          prefs.getBool('dark_mode') == true ? ThemeMode.dark : ThemeMode.light;
      final savedStart = prefs.getInt('usage_start_millis');
      if (savedStart != null) {
        usageStart = DateTime.fromMillisecondsSinceEpoch(savedStart);
      }
      final savedTodayReset = prefs.getInt('today_reset_millis');
      if (savedTodayReset != null) {
        todayResetAt = DateTime.fromMillisecondsSinceEpoch(savedTodayReset);
        _loadTodayBaseline(prefs.getString('today_reset_baseline'));
      }
      final savedDayBaselines = prefs.getString('day_baselines');
      if (savedDayBaselines != null) {
        try {
          _loadDayBaselines(jsonDecode(savedDayBaselines));
        } catch (_) {
          // Ignore a corrupted optional baseline cache.
        }
      }
      if (todayResetAt != null) {
        _dayBaselines[_dateLabel(todayResetAt!.millisecondsSinceEpoch)] = {
          'mobileBytes': _todayBaselineMobileBytes,
          'wifiBytes': _todayBaselineWifiBytes,
          'appUsage': _todayBaselineApps,
          'appWifiUsage': _todayBaselineAppWifi,
          'appMobileUsage': _todayBaselineAppMobile,
        };
      }
      _loadPolicyState(prefs.getString('app_policies'));
      appSort = prefs.getString('app_sort') ?? appSort;
      _loadRules(prefs.getString('rules'));
      _loadProfiles(prefs.getString('profiles'));
      _loadCachedDeviceData(
        prefs.getString('cached_apps'),
        prefs.getString('cached_daily_records'),
        prefs.getString('cached_device_date'),
      );
    } catch (error) {
      dataError = 'تعذر قراءة الإعدادات المحلية: $error';
    }

    // Local preferences are enough to render the first frame. Device and
    // NetworkStats calls are intentionally started after that frame so a slow
    // PackageManager/Usage Access query cannot hold the splash screen.
    initialized = true;
    notifyListeners();
    unawaited(refreshDeviceData());
    unawaited(refreshRealtimeSpeed());
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await refreshRealtimeSpeed();
    });
    _deviceRefreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_appInForeground && initialized && !isRefreshing) {
        await refreshDeviceData();
      }
    });
    _currentUsageTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_appInForeground &&
          initialized &&
          nativeSupported &&
          usageAccessGranted &&
          !_currentUsageRefreshing) {
        await refreshCurrentUsage();
      }
    });
  }

  void _loadCachedDeviceData(
      String? encodedApps, String? encodedRecords, String? cachedDate) {
    try {
      if (encodedApps != null) {
        final rawApps = jsonDecode(encodedApps);
        if (rawApps is List) {
          apps = rawApps
              .whereType<Map>()
              .map((row) => ManagedApp.fromJson(Map<String, dynamic>.from(row)))
              .where((app) => app.packageName.isNotEmpty)
              .toList();
          final today = _dateLabel(DateTime.now().millisecondsSinceEpoch);
          if (cachedDate != today) {
            apps = apps
                .map((app) =>
                    app.copyWith(usageBytes: 0, wifiBytes: 0, mobileBytes: 0))
                .toList();
          }
          if (apps.isNotEmpty) lastRefresh = DateTime.now();
        }
      }
      if (encodedRecords != null) {
        final rawRecords = jsonDecode(encodedRecords);
        if (rawRecords is List) {
          dailyRecords = rawRecords
              .whereType<Map>()
              .map((row) {
                final item = Map<String, dynamic>.from(row);
                return DailyUsageRecord(
                  dateLabel: '${item['dateLabel'] ?? ''}',
                  mobileBytes: _int(item['mobileBytes']),
                  wifiBytes: _int(item['wifiBytes']),
                  dayStartMillis: _intOrNull(item['dayStartMillis']),
                  appUsage: _mapIntValues(item['appUsage']),
                  appWifiUsage: _mapIntValues(item['appWifiUsage']),
                  appMobileUsage: _mapIntValues(item['appMobileUsage']),
                );
              })
              .where((record) => record.dateLabel.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // A stale or partially written cache must never block the real refresh.
    }
  }

  Future<void> refreshDeviceData({bool force = false}) async {
    if (isRefreshing) return;
    final nowAttempt = DateTime.now();
    final previousAttempt = _lastDeviceRefreshAttemptAt;
    if (!force &&
        previousAttempt != null &&
        nowAttempt.difference(previousAttempt) < const Duration(seconds: 3)) {
      return;
    }
    _lastDeviceRefreshAttemptAt = nowAttempt;
    isRefreshing = true;
    dataError = null;
    notifyListeners();
    try {
      final permission = await NativeConnector.getPermissionStatus();
      nativeSupported = permission['supported'] == true;
      usageAccessGranted = permission['usageAccessGranted'] == true;
      notificationsGranted = permission['notificationsGranted'] == true;
      vpnPrepared = permission['vpnPrepared'] == true;
      final vpnError = '${permission['vpnError'] ?? ''}'.trim();
      final speedServiceError =
          '${permission['speedServiceError'] ?? ''}'.trim();
      final limitMonitorError =
          '${permission['limitMonitorError'] ?? ''}'.trim();
      if (vpnError.isNotEmpty) {
        dataError = 'خدمة VPN لا تعمل: $vpnError';
      } else if (speedServiceError.isNotEmpty) {
        dataError = 'عداد السرعة لم يبدأ: $speedServiceError';
      } else if (limitMonitorError.isNotEmpty) {
        dataError = 'مراقبة الحدود لم تبدأ: $limitMonitorError';
      }
      if (!nativeSupported) {
        dataError =
            'تعمل هذه الميزة على Android فقط؛ لا توجد بيانات جهاز حقيقية على هذه المنصة.';
        return;
      }

      final now = DateTime.now();
      final installedFuture = NativeConnector.getInstalledApps();
      final historyFuture = usageAccessGranted
          ? NativeConnector.getUsageHistory(start: usageStart, end: now)
          : Future.value(const <Map<String, dynamic>>[]);
      final installed = await installedFuture;
      // PackageManager is usually faster than NetworkStats. Publish the real
      // app list immediately while preserving cached/last-known daily values.
      apps = _mergeDeviceApps(installed);
      notifyListeners();
      final history = await historyFuture;
      final statsError = usageAccessGranted
          ? await NativeConnector.getNetworkStatsError()
          : null;
      if (statsError != null && statsError.isNotEmpty) {
        dataError = 'تعذر قراءة إحصاءات الشبكة: $statsError';
      }
      if (usageAccessGranted) {
        dailyRecords = _parseHistory(history, installed);
        if (_rolloverTodayIfNeeded(now)) {
          await _persist();
        }
        _applyTodayBaseline(now);
        apps = _applyTodayUsageToApps();
      }
      _applyLimitRules();
      if (_blockedPackages.isNotEmpty && vpnPrepared && !isVpnActive) {
        final vpnResult = await _ensureVpnForBlockedApps();
        if (vpnResult.startsWith('ERROR')) {
          dataError = 'تعذر تطبيق الحظر: $vpnResult';
        }
      } else {
        await _syncVpnPolicies();
      }
      final vpnStatus = await NativeConnector.getRealtimeSpeed();
      isVpnActive = vpnStatus['vpnActive'] == true;
      limitMonitorRunning = permission['limitMonitorRunning'] == true;
      lastRefresh = DateTime.now();
      if (!usageAccessGranted) {
        dataError =
            'تم تحميل التطبيقات، لكن إذن الوصول إلى بيانات الاستخدام غير ممنوح بعد.';
      }
      await _ensureLimitMonitor();
      await _persist();
    } catch (error) {
      dataError = 'تعذر تحديث بيانات الجهاز: $error';
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUsage({bool force = false}) async {
    if (_currentUsageRefreshing || !nativeSupported || !usageAccessGranted) {
      return;
    }
    _currentUsageRefreshing = true;
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final rawRows =
          await NativeConnector.getUsageStats(start: dayStart, end: now);
      final record = _parseCurrentUsage(rawRows, apps, dayStart);
      if (record == null) return;
      final adjusted = _applyBaselineToRecord(record);
      final todayLabel = adjusted.dateLabel;
      dailyRecords = [
        ...dailyRecords.where((item) => item.dateLabel != todayLabel),
        if (adjusted.totalBytes > 0) adjusted,
      ]..sort(
          (a, b) => (b.dayStartMillis ?? 0).compareTo(a.dayStartMillis ?? 0));
      apps = _applyTodayUsageToApps();
      lastRefresh = DateTime.now();
      notifyListeners();
      if (force) await _persist();
    } catch (error) {
      dataError = 'تعذر تحديث استهلاك اليوم: $error';
    } finally {
      _currentUsageRefreshing = false;
    }
  }

  Future<void> refreshRealtimeSpeed() async {
    try {
      final result = await NativeConnector.getRealtimeSpeed();
      if (result['supported'] == true) {
        downloadKbps = _double(result['downloadKbps']);
        uploadKbps = _double(result['uploadKbps']);
        if (downloadKbps > peakDownloadKbps) peakDownloadKbps = downloadKbps;
        downloadHistory.add(downloadKbps);
        if (downloadHistory.length > 60) downloadHistory.removeAt(0);
        networkType = '${result['networkType'] ?? 'غير معروف'}';
        dailyWifiUsageBytes = _int(result['dailyWifiBytes']);
        dailyMobileUsageBytes = _int(result['dailyMobileBytes']);
        final serviceRunning = result['serviceRunning'] == true;
        speedServiceEnabled = serviceRunning;
        isVpnActive = result['vpnActive'] == true;
        // Android may reclaim a foreground service on vendor ROMs or after
        // memory pressure. Recover it while the user-enabled preference is on.
        if (!serviceRunning &&
            _prefs?.getBool('speed_service_enabled') == true &&
            notificationsGranted &&
            !_serviceRecoveryInFlight) {
          _serviceRecoveryInFlight = true;
          unawaited(() async {
            try {
              await NativeConnector.startSpeedService();
            } finally {
              _serviceRecoveryInFlight = false;
            }
          }());
        }
        final nativeError = '${result['lastError'] ?? ''}'.trim();
        final trafficSupported = result['trafficSupported'] != false;
        if (!trafficSupported) {
          dataError = 'عدادات حركة الشبكة غير مدعومة على هذا الجهاز.';
        } else if (!speedServiceEnabled && nativeError.isNotEmpty) {
          dataError = 'تعذر تشغيل عداد السرعة: $nativeError';
        }
        notifyListeners();
      }
    } catch (_) {
      // The UI keeps the last known real value when the native service is unavailable.
    }
  }

  Future<String> startSpeedService() async {
    final permissionResult =
        await NativeConnector.requestNotificationPermission();
    notificationsGranted = permissionResult == 'GRANTED';
    if (permissionResult != 'GRANTED') return permissionResult;
    final result = await NativeConnector.startSpeedService();
    if (result == 'STARTED' || result == 'ALREADY_RUNNING') {
      speedServiceEnabled = true;
      await _persist();
      notifyListeners();
    }
    return result;
  }

  Future<String> stopSpeedService() async {
    final result = await NativeConnector.stopSpeedService();
    if (result == 'STOPPED' || result == 'NOT_RUNNING') {
      speedServiceEnabled = false;
      await _persist();
      notifyListeners();
    }
    return result;
  }

  Future<String> toggleVpn() async {
    final result = isVpnActive
        ? await NativeConnector.stopVpn()
        : await NativeConnector.startVpn(
            blockedPackages: _manualBlockedPackages,
            automaticPackages: _automaticBlockedPackages,
          );
    if (result == 'STARTED' || result == 'STOPPED' || result == 'UPDATED') {
      isVpnActive = result == 'STARTED' || (result == 'UPDATED' && isVpnActive);
      notifyListeners();
    }
    return result;
  }

  Future<void> toggleNotifications() async {
    notificationsEnabled = !notificationsEnabled;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleLimitMonitor() async {
    limitMonitoringEnabled = !limitMonitoringEnabled;
    await _persist();
    if (!limitMonitoringEnabled) {
      limitMonitorRunning = false;
      await NativeConnector.stopLimitMonitor();
      await NativeConnector.clearAutomaticBlocks();
      apps = apps
          .map((app) => app.autoBlocked
              ? app.copyWith(accessMode: AccessMode.allowed, autoBlocked: false)
              : app)
          .toList();
      await _persist();
    } else {
      final permission = await NativeConnector.requestNotificationPermission();
      notificationsGranted = permission == 'GRANTED';
      if (permission != 'GRANTED') {
        dataError = 'لتشغيل مراقبة الحدود، اسمح بإشعارات الخدمة أولًا.';
      } else {
        await _ensureLimitMonitor();
      }
    }
    notifyListeners();
  }

  Future<void> toggleSpeedMeterAppBar() async {
    speedMeterInAppBar = !speedMeterInAppBar;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _persist();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingDone = true;
    await _persist();
    notifyListeners();
  }

  Future<void> markPermissionPromptShown() async {
    permissionPromptShown = true;
    await _persist();
    notifyListeners();
  }

  void setAppForeground(bool value) {
    _appInForeground = value;
  }

  void setTab(int value) {
    selectedTab = value.clamp(0, 4).toInt();
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setFilter(String value) {
    appFilter = value;
    notifyListeners();
  }

  void setSort(String value) {
    appSort = value;
    notifyListeners();
  }

  void setPeriod(int value) {
    selectedPeriod = value.clamp(0, 2).toInt();
    notifyListeners();
  }

  Future<void> toggleRule(String id) async {
    rules = rules
        .map((rule) =>
            rule.id == id ? rule.copyWith(enabled: !rule.enabled) : rule)
        .toList();
    await _persist();
    await _ensureLimitMonitor();
    notifyListeners();
  }

  Future<void> addCustomRule(
      {required String title, required String description}) async {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    rules = [
      ...rules,
      SmartRule(
          id: id,
          title: title,
          description: description,
          icon: Icons.tune_rounded,
          enabled: true,
          color: AppColors.primary),
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> activateProfile(String id) async {
    final profile = profiles.firstWhere((item) => item.id == id);
    final nextApps = apps.map((app) {
      if (id == 'saver' &&
          app.usageBytes > 0 &&
          app.usageBytes >= _highestUsage / 3) {
        return app.copyWith(
            accessMode: AccessMode.wifiOnly, autoBlocked: false);
      }
      if ((id == 'study' || id == 'work') && _isEntertainment(app)) {
        return app.copyWith(accessMode: AccessMode.blocked, autoBlocked: false);
      }
      return app;
    }).toList();
    apps = nextApps;
    profiles = profiles
        .map((item) => item.copyWith(active: item.id == profile.id))
        .toList();
    final blocked = _blockedPackages;
    if (blocked.isNotEmpty && !isVpnActive) {
      final result = await _ensureVpnForBlockedApps();
      if (result.startsWith('ERROR')) {
        dataError = 'تعذر تشغيل VPN للبروفايل: $result';
      }
    } else {
      await _syncVpnPolicies();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    apps = apps
        .map((app) =>
            app.id == id ? app.copyWith(isFavorite: !app.isFavorite) : app)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<String> updateMode(String id, AccessMode mode) async {
    apps = apps
        .map((app) => app.id == id
            ? app.copyWith(accessMode: mode, autoBlocked: false)
            : app)
        .toList();
    var result = 'LOCAL_ONLY';
    if ((mode == AccessMode.blocked || mode == AccessMode.backgroundBlocked) && !isVpnActive) {
      result = await NativeConnector.startVpn(
        blockedPackages: _manualBlockedPackages,
        automaticPackages: _automaticBlockedPackages,
        backgroundPackages: _backgroundBlockedPackages,
      );
      if (result == 'STARTED' || result == 'ALREADY_RUNNING') {
        isVpnActive = true;
      }
    } else {
      result = await _syncVpnPolicies();
    }
    await _persist();
    notifyListeners();
    return result;
  }

  Future<String> updateLimit(String id, int limitBytes) async {
    final target = apps.firstWhere((app) => app.id == id,
        orElse: () => throw StateError('التطبيق غير موجود'));
    final shouldBlock = limitBytes > 0 && target.usageBytes >= limitBytes;
    apps = apps.map((app) {
      if (app.id != id) return app;
      return app.copyWith(
        limitBytes: limitBytes,
        accessMode: shouldBlock
            ? AccessMode.blocked
            : (app.autoBlocked ? AccessMode.allowed : app.accessMode),
        autoBlocked: shouldBlock,
      );
    }).toList();
    await _persist();
    final result = shouldBlock && !isVpnActive
        ? await _ensureVpnForBlockedApps()
        : await _syncVpnPolicies();
    await _ensureLimitMonitor();
    notifyListeners();
    return result;
  }

  Future<void> resetStats() async {
    usageStart = DateTime.now();
    todayResetAt = usageStart;
    _clearTodayBaseline();
    _dayBaselines.clear();
    dailyRecords = <DailyUsageRecord>[];
    apps = apps
        .map((app) => app.autoBlocked
            ? app.copyWith(accessMode: AccessMode.allowed, autoBlocked: false)
            : app)
        .toList();
    await NativeConnector.clearAutomaticBlocks();
    await _persist();
    await refreshDeviceData();
  }

  Future<void> resetDayStats(String dateLabel) async {
    final record = dailyRecords
        .cast<DailyUsageRecord?>()
        .firstWhere((item) => item?.dateLabel == dateLabel, orElse: () => null);
    if (record == null) return;
    final existing = _dayBaselines[dateLabel] ?? const <String, dynamic>{};
    final baseline = {
      'mobileBytes': _int(existing['mobileBytes']) + record.mobileBytes,
      'wifiBytes': _int(existing['wifiBytes']) + record.wifiBytes,
      'appUsage':
          _addUsageMaps(_mapIntValues(existing['appUsage']), record.appUsage),
      'appWifiUsage': _addUsageMaps(
          _mapIntValues(existing['appWifiUsage']), record.appWifiUsage),
      'appMobileUsage': _addUsageMaps(
          _mapIntValues(existing['appMobileUsage']), record.appMobileUsage),
    };
    _dayBaselines[dateLabel] = baseline;
    final todayLabel = _dateLabel(DateTime.now().millisecondsSinceEpoch);
    if (dateLabel == todayLabel) {
      todayResetAt = DateTime.now();
      _todayBaselineMobileBytes = _int(baseline['mobileBytes']);
      _todayBaselineWifiBytes = _int(baseline['wifiBytes']);
      _todayBaselineApps = _mapIntValues(baseline['appUsage']);
      _todayBaselineAppWifi = _mapIntValues(baseline['appWifiUsage']);
      _todayBaselineAppMobile = _mapIntValues(baseline['appMobileUsage']);
    }
    await _persist();
    await refreshDeviceData();
  }

  Future<void> resetTodayStats() async {
    // Read the unadjusted day once so the reset removes only usage accumulated
    // before this action while preserving previous days in the system history.
    todayResetAt = null;
    final todayLabel = _dateLabel(DateTime.now().millisecondsSinceEpoch);
    _dayBaselines.remove(todayLabel);
    _clearTodayBaseline();
    await refreshDeviceData();
    final rawToday = dailyRecords.cast<DailyUsageRecord?>().firstWhere(
        (record) => record?.dateLabel == todayLabel,
        orElse: () => null);
    final now = DateTime.now();
    todayResetAt = now;
    _todayBaselineMobileBytes = rawToday?.mobileBytes ?? 0;
    _todayBaselineWifiBytes = rawToday?.wifiBytes ?? 0;
    _todayBaselineApps = rawToday == null
        ? <String, int>{}
        : Map<String, int>.from(rawToday.appUsage);
    _todayBaselineAppWifi = rawToday == null
        ? <String, int>{}
        : Map<String, int>.from(rawToday.appWifiUsage);
    _todayBaselineAppMobile = rawToday == null
        ? <String, int>{}
        : Map<String, int>.from(rawToday.appMobileUsage);
    _dayBaselines[todayLabel] = {
      'mobileBytes': _todayBaselineMobileBytes,
      'wifiBytes': _todayBaselineWifiBytes,
      'appUsage': _todayBaselineApps,
      'appWifiUsage': _todayBaselineAppWifi,
      'appMobileUsage': _todayBaselineAppMobile,
    };
    await _persist();
    await refreshDeviceData();
  }

  Future<void> resetPolicies() async {
    apps = apps
        .map((app) => app.copyWith(
              accessMode: AccessMode.allowed,
              limitBytes: 0,
              autoBlocked: false,
              isRuleEnabled: true,
            ))
        .toList();
    await NativeConnector.clearAutomaticBlocks();
    await _syncVpnPolicies();
    await _ensureLimitMonitor();
    await _persist();
    notifyListeners();
  }

  Future<void> resetRules() async {
    rules = const [
      SmartRule(
        id: 'limit',
        title: 'إشعار عند تجاوز حد التطبيق',
        description:
            'يراقب الاستهلاك الحقيقي ويبلغك عند وصول التطبيق إلى الحد.',
        icon: Icons.data_usage_rounded,
        enabled: true,
        color: AppColors.indigo,
      ),
      SmartRule(
        id: 'battery',
        title: 'توفير البطارية والبيانات',
        description: 'يعرض التطبيقات ذات الاستهلاك الأعلى لتتخذ قرارًا واضحًا.',
        icon: Icons.battery_saver_rounded,
        enabled: true,
        color: AppColors.teal,
      ),
      SmartRule(
        id: 'study',
        title: 'وقت التركيز والدراسة',
        description: 'يطبق سياسة التطبيقات التي تختارها أثناء الوقت المحدد.',
        icon: Icons.school_rounded,
        enabled: false,
        color: Colors.orange,
      ),
    ];
    _applyLimitRules();
    await _syncVpnPolicies();
    await _ensureLimitMonitor();
    await _persist();
    notifyListeners();
  }

  Map<String, dynamic> backupData() => {
        'schemaVersion': 2,
        'app': 'الأدريسي نت',
        'exportedAt': DateTime.now().toIso8601String(),
        'usageStart': usageStart.toIso8601String(),
        'todayResetAt': todayResetAt?.toIso8601String(),
        'todayResetBaseline': {
          'mobileBytes': _todayBaselineMobileBytes,
          'wifiBytes': _todayBaselineWifiBytes,
          'appUsage': _todayBaselineApps,
          'appWifiUsage': _todayBaselineAppWifi,
          'appMobileUsage': _todayBaselineAppMobile,
        },
        'dayBaselines': _dayBaselines,
        'onboardingDone': onboardingDone,
        'permissionPromptShown': permissionPromptShown,
        'notificationsEnabled': notificationsEnabled,
        'speedMeterInAppBar': speedMeterInAppBar,
        'speedServiceEnabled': speedServiceEnabled,
        'limitMonitoringEnabled': limitMonitoringEnabled,
        'appSort': appSort,
        'themeMode': themeMode.name,
        'apps': apps.map((app) => app.toJson()).toList(),
        'rules': rules.map((rule) => rule.toJson()).toList(),
        'profiles': profiles
            .map((profile) => {'id': profile.id, 'active': profile.active})
            .toList(),
      };

  Future<bool> importBackupData(Map<String, dynamic> backup) async {
    if (backup['schemaVersion'] is! num ||
        (backup['schemaVersion'] as num).toInt() < 1) {
      return false;
    }
    final rawApps = backup['apps'];
    if (rawApps is List) {
      final importedByPackage = <String, Map<String, dynamic>>{};
      for (final raw in rawApps.whereType<Map>()) {
        final map = <String, dynamic>{};
        raw.forEach((key, value) => map[key.toString()] = value);
        final package = map['packageName'];
        if (package is String) importedByPackage[package] = map;
      }
      apps = apps.map((app) {
        final saved = importedByPackage[app.packageName];
        if (saved == null) return app;
        final modeName = saved['accessMode'];
        final mode = AccessMode.values.firstWhere(
            (item) => item.name == modeName,
            orElse: () => app.accessMode);
        return app.copyWith(
          accessMode: mode,
          isFavorite: saved['isFavorite'] == true,
          limitBytes: _int(saved['limitBytes']),
          warningPercent:
              _int(saved['warningPercent'], fallback: app.warningPercent),
          isRuleEnabled: saved['isRuleEnabled'] != false,
          autoBlocked: false,
        );
      }).toList();
    }
    if (backup['usageStart'] is String) {
      usageStart =
          DateTime.tryParse(backup['usageStart'] as String) ?? usageStart;
    }
    if (backup['todayResetAt'] is String) {
      todayResetAt = DateTime.tryParse(backup['todayResetAt'] as String);
      _loadTodayBaselineMap(backup['todayResetBaseline']);
    }
    _loadDayBaselines(backup['dayBaselines']);
    onboardingDone = backup['onboardingDone'] == true;
    permissionPromptShown = backup['permissionPromptShown'] == true;
    notificationsEnabled = backup['notificationsEnabled'] != false;
    speedMeterInAppBar = backup['speedMeterInAppBar'] != false;
    speedServiceEnabled = backup['speedServiceEnabled'] == true;
    limitMonitoringEnabled = backup['limitMonitoringEnabled'] is bool
        ? backup['limitMonitoringEnabled'] as bool
        : limitMonitoringEnabled;
    appSort =
        backup['appSort'] is String ? backup['appSort'] as String : appSort;
    themeMode = backup['themeMode'] == ThemeMode.dark.name
        ? ThemeMode.dark
        : ThemeMode.light;
    _importRules(backup['rules']);
    _importProfiles(backup['profiles']);
    await _persist();
    await _syncVpnPolicies();
    await _ensureLimitMonitor();
    notifyListeners();
    return true;
  }

  Future<void> openUsageAccessSettings() =>
      NativeConnector.openUsageAccessSettings();

  Future<String> requestVpnPermission() async {
    final result = await NativeConnector.requestVpnPermission();
    await refreshDeviceData();
    return result;
  }

  List<String> get _blockedPackages => apps
      .where((app) => app.accessMode == AccessMode.blocked)
      .map((app) => app.packageName)
      .toList();
  List<String> get _backgroundBlockedPackages => apps
      .where((app) => app.accessMode == AccessMode.backgroundBlocked)
      .map((app) => app.packageName)
      .toList();
  List<String> get _manualBlockedPackages => apps
      .where((app) => app.accessMode == AccessMode.blocked && !app.autoBlocked)
      .map((app) => app.packageName)
      .toList();
  List<String> get _automaticBlockedPackages => apps
      .where((app) => app.autoBlocked)
      .map((app) => app.packageName)
      .toList();
  int get _highestUsage => apps.fold(
      0, (highest, app) => app.usageBytes > highest ? app.usageBytes : highest);

  void _applyLimitRules() {
    final limitRuleEnabled =
        rules.any((rule) => rule.id == 'limit' && rule.enabled);
    apps = applyLocalLimitPolicies(
      apps,
      limitRuleEnabled: limitRuleEnabled,
    );
  }

  Future<String> _ensureVpnForBlockedApps() async {
    final packages = <String>{
      ..._blockedPackages,
      ..._backgroundBlockedPackages,
    };
    if (packages.isEmpty) return 'NO_BLOCKED_APPS';
    final result = await NativeConnector.startVpn(
      blockedPackages: _manualBlockedPackages,
      automaticPackages: _automaticBlockedPackages,
      backgroundPackages: _backgroundBlockedPackages,
    );
    if (result == 'STARTED' || result == 'ALREADY_RUNNING') isVpnActive = true;
    return result;
  }

  Future<String> _syncVpnPolicies() async {
    final packages = <String>{
      ..._blockedPackages,
      ..._backgroundBlockedPackages,
    };
    if (!isVpnActive) {
      return packages.isEmpty ? 'VPN_INACTIVE' : 'VPN_PERMISSION_REQUIRED';
    }
    final result = await NativeConnector.updateVpnPolicies(
      _manualBlockedPackages,
      automaticPackages: _automaticBlockedPackages,
      backgroundPackages: _backgroundBlockedPackages,
    );
    if (_manualBlockedPackages.isEmpty &&
        _automaticBlockedPackages.isEmpty &&
        _backgroundBlockedPackages.isEmpty &&
        (result == 'UPDATED' || result == 'STOPPED')) {
      isVpnActive = false;
    }
    return result;
  }

  Future<void> _ensureLimitMonitor() async {
    final limitRuleEnabled =
        rules.any((rule) => rule.id == 'limit' && rule.enabled);
    final needsMonitor = limitMonitoringEnabled &&
        nativeSupported &&
        usageAccessGranted &&
        limitRuleEnabled &&
        apps.any((app) => app.limitBytes > 0 && app.isRuleEnabled);
    if (!needsMonitor) {
      limitMonitorRunning = false;
      var localStateChanged = false;
      apps = apps.map((app) {
        if (!app.autoBlocked) return app;
        localStateChanged = true;
        return app.copyWith(accessMode: AccessMode.allowed, autoBlocked: false);
      }).toList();
      if (nativeSupported) {
        await NativeConnector.stopLimitMonitor();
        await NativeConnector.clearAutomaticBlocks();
      }
      if (localStateChanged) await _persist();
      if (_blockedPackages.isEmpty) isVpnActive = false;
      return;
    }
    if (!notificationsGranted) {
      limitMonitorRunning = false;
      dataError = 'مراقبة الحدود تحتاج إذن الإشعارات حتى تعمل كخدمة خلفية.';
      return;
    }
    final result = await NativeConnector.startLimitMonitor();
    limitMonitorRunning = result == 'STARTED' || result == 'ALREADY_RUNNING';
  }

  bool _isEntertainment(ManagedApp app) {
    final value = '${app.name} ${app.packageName}'.toLowerCase();
    return value.contains('youtube') ||
        value.contains('tiktok') ||
        value.contains('instagram') ||
        value.contains('facebook') ||
        value.contains('netflix');
  }

  List<ManagedApp> _mergeDeviceApps(List<Map<String, dynamic>> installed) {
    final saved = _policyMap;
    final cachedByPackage = <String, ManagedApp>{
      for (final app in apps) app.packageName: app,
    };
    return installed
        .map((raw) {
          final packageName = '${raw['packageName'] ?? ''}';
          final old = saved[packageName] ?? const <String, dynamic>{};
          final cached = cachedByPackage[packageName];
          final mode = AccessMode.values.firstWhere(
              (item) => item.name == old['accessMode'],
              orElse: () => AccessMode.allowed);
          return ManagedApp(
            id: packageName,
            name: '${raw['name'] ?? packageName}',
            packageName: packageName,
            icon: Icons.apps_rounded,
            iconBytes: NativeConnector.iconBytes(raw['iconBytes']),
            usageBytes: cached?.usageBytes ?? 0,
            wifiBytes: cached?.wifiBytes ?? 0,
            mobileBytes: cached?.mobileBytes ?? 0,
            accessMode: mode,
            isFavorite: old['isFavorite'] == true,
            limitBytes: _int(old['limitBytes']),
            warningPercent: _int(old['warningPercent'], fallback: 80),
            isRuleEnabled: old['isRuleEnabled'] != false,
            uid: _intOrNull(raw['uid']),
            isSystemApp: raw['isSystemApp'] == true,
            isLaunchable: raw['isLaunchable'] != false,
            requestedPermissions: _strings(raw['requestedPermissions']),
            grantedPermissions: _strings(raw['grantedPermissions']),
          );
        })
        .where((app) => app.packageName.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  DailyUsageRecord? _parseCurrentUsage(List<Map<String, dynamic>> raw,
      List<ManagedApp> currentApps, DateTime day) {
    if (raw.isEmpty) return null;
    final packagesByUid = <int, List<String>>{};
    for (final app in currentApps) {
      final uid = app.uid;
      if (uid != null) {
        packagesByUid.putIfAbsent(uid, () => <String>[]).add(app.packageName);
      }
    }
    final appUsage = <String, int>{};
    final appWifiUsage = <String, int>{};
    final appMobileUsage = <String, int>{};
    var wifiBytes = 0;
    var mobileBytes = 0;
    for (final rawRow in raw) {
      final uid = _intOrNull(rawRow['uid']);
      if (uid == null || uid < 0) continue;
      final wifi = _int(rawRow['wifiBytes']);
      final mobile = _int(rawRow['mobileBytes']);
      wifiBytes += wifi;
      mobileBytes += mobile;
      final packages = packagesByUid[uid] ?? <String>[];
      final key = packages.isEmpty
          ? 'UID $uid'
          : packages.length == 1
              ? packages.first
              : packages.join(' + ');
      appUsage[key] = (appUsage[key] ?? 0) + wifi + mobile;
      appWifiUsage[key] = (appWifiUsage[key] ?? 0) + wifi;
      appMobileUsage[key] = (appMobileUsage[key] ?? 0) + mobile;
    }
    if (wifiBytes == 0 && mobileBytes == 0 && appUsage.isEmpty) return null;
    return DailyUsageRecord(
      dateLabel: _dateLabel(day.millisecondsSinceEpoch),
      dayStartMillis:
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
      mobileBytes: mobileBytes,
      wifiBytes: wifiBytes,
      appUsage: appUsage,
      appWifiUsage: appWifiUsage,
      appMobileUsage: appMobileUsage,
    );
  }

  List<DailyUsageRecord> _parseHistory(
      List<Map<String, dynamic>> raw, List<Map<String, dynamic>> installed) {
    final packagesByUid = <int, List<String>>{};
    for (final app in installed) {
      final uid = _intOrNull(app['uid']);
      final packageName = '${app['packageName'] ?? ''}'.trim();
      if (uid != null && packageName.isNotEmpty) {
        packagesByUid.putIfAbsent(uid, () => <String>[]).add(packageName);
      }
    }
    final rows = raw
        .map((item) {
          final date = item['dateLabel'] is String
              ? item['dateLabel'] as String
              : _dateLabel(item['dayStartMillis']);
          final appUsage = <String, int>{};
          final appWifiUsage = <String, int>{};
          final appMobileUsage = <String, int>{};
          final uidRows = item['uidUsage'];
          if (uidRows is List) {
            for (final rawRow in uidRows) {
              if (rawRow is! Map) continue;
              final uid = _intOrNull(rawRow['uid']);
              if (uid == null) continue;
              final packages = packagesByUid[uid] ?? <String>[];
              final key = packages.isEmpty
                  ? 'UID $uid'
                  : packages.length == 1
                      ? packages.first
                      : packages.join(' + ');
              appUsage[key] = (appUsage[key] ?? 0) + _int(rawRow['totalBytes']);
              appWifiUsage[key] =
                  (appWifiUsage[key] ?? 0) + _int(rawRow['wifiBytes']);
              appMobileUsage[key] =
                  (appMobileUsage[key] ?? 0) + _int(rawRow['mobileBytes']);
            }
          }
          return DailyUsageRecord(
            dateLabel: date,
            dayStartMillis: _intOrNull(item['dayStartMillis']),
            mobileBytes: _int(item['mobileBytes']),
            wifiBytes: _int(item['wifiBytes']),
            appUsage: appUsage,
            appWifiUsage: appWifiUsage,
            appMobileUsage: appMobileUsage,
          );
        })
        .where((row) => row.totalBytes > 0)
        .toList();
    rows.sort((a, b) {
      final aTime = a.dayStartMillis ?? 0;
      final bTime = b.dayStartMillis ?? 0;
      return bTime.compareTo(aTime);
    });
    return rows;
  }

  String _dateLabel(dynamic millis) {
    final date = millis is num
        ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
        : DateTime.now();
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _recordDay(DailyUsageRecord record) {
    if (record.dayStartMillis != null) {
      final value = DateTime.fromMillisecondsSinceEpoch(record.dayStartMillis!);
      return DateTime(value.year, value.month, value.day);
    }
    final parts = record.dateLabel.split('/');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime(1970);
  }

  bool _rolloverTodayIfNeeded(DateTime now) {
    final reset = todayResetAt;
    if (reset == null || _sameDay(reset, now)) return false;
    _clearTodayBaseline();
    return true;
  }

  DailyUsageRecord _applyBaselineToRecord(DailyUsageRecord record) {
    final baseline = _dayBaselines[record.dateLabel];
    if (baseline == null) return record;
    return record.copyWith(
      mobileBytes: (record.mobileBytes - _int(baseline['mobileBytes']))
          .clamp(0, record.mobileBytes)
          .toInt(),
      wifiBytes: (record.wifiBytes - _int(baseline['wifiBytes']))
          .clamp(0, record.wifiBytes)
          .toInt(),
      appUsage: _subtractUsageMap(
          record.appUsage, _mapIntValues(baseline['appUsage'])),
      appWifiUsage: _subtractUsageMap(
          record.appWifiUsage, _mapIntValues(baseline['appWifiUsage'])),
      appMobileUsage: _subtractUsageMap(
          record.appMobileUsage, _mapIntValues(baseline['appMobileUsage'])),
    );
  }

  void _applyTodayBaseline(DateTime now) {
    dailyRecords = dailyRecords
        .map(_applyBaselineToRecord)
        .where((record) => record.totalBytes > 0)
        .toList();
  }

  List<ManagedApp> _applyTodayUsageToApps() {
    final today = todayRecord;
    if (today == null) {
      return apps
          .map((app) =>
              app.copyWith(usageBytes: 0, wifiBytes: 0, mobileBytes: 0))
          .toList();
    }
    return apps.map((app) {
      final usage = _usageForPackage(today.appUsage, app.packageName);
      final wifi = _usageForPackage(today.appWifiUsage, app.packageName);
      final mobile = _usageForPackage(today.appMobileUsage, app.packageName);
      return app.copyWith(
          usageBytes: usage, wifiBytes: wifi, mobileBytes: mobile);
    }).toList();
  }

  int _usageForPackage(Map<String, int> values, String packageName) {
    final direct = values[packageName];
    if (direct != null) return direct;
    for (final entry in values.entries) {
      final packages = entry.key.split(' + ');
      if (packages.contains(packageName)) {
        // A shared UID is one indivisible Android counter. Assign it once to
        // the first package rather than duplicating bytes across app cards.
        return packages.first == packageName ? entry.value : 0;
      }
    }
    return 0;
  }

  Map<String, int> _addUsageMaps(
      Map<String, int> first, Map<String, int> second) {
    final result = <String, int>{...first};
    for (final entry in second.entries) {
      result[entry.key] = (result[entry.key] ?? 0) + entry.value;
    }
    return result;
  }

  Map<String, int> _subtractUsageMap(
      Map<String, int> values, Map<String, int> baseline) {
    final result = <String, int>{};
    for (final entry in values.entries) {
      final remaining = entry.value - (baseline[entry.key] ?? 0);
      if (remaining > 0) result[entry.key] = remaining;
    }
    return result;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _clearTodayBaseline() {
    todayResetAt = null;
    _todayBaselineMobileBytes = 0;
    _todayBaselineWifiBytes = 0;
    _todayBaselineApps = <String, int>{};
    _todayBaselineAppWifi = <String, int>{};
    _todayBaselineAppMobile = <String, int>{};
  }

  void _loadTodayBaseline(String? encoded) {
    if (encoded == null) return;
    try {
      _loadTodayBaselineMap(jsonDecode(encoded));
    } catch (_) {
      _clearTodayBaseline();
    }
  }

  void _loadTodayBaselineMap(dynamic raw) {
    if (raw is! Map) return;
    _todayBaselineMobileBytes = _int(raw['mobileBytes']);
    _todayBaselineWifiBytes = _int(raw['wifiBytes']);
    _todayBaselineApps = _mapIntValues(raw['appUsage']);
    _todayBaselineAppWifi = _mapIntValues(raw['appWifiUsage']);
    _todayBaselineAppMobile = _mapIntValues(raw['appMobileUsage']);
  }

  void _loadDayBaselines(dynamic raw) {
    if (raw is! Map) return;
    raw.forEach((key, value) {
      if (value is Map) {
        _dayBaselines['$key'] = {
          'mobileBytes': _int(value['mobileBytes']),
          'wifiBytes': _int(value['wifiBytes']),
          'appUsage': _mapIntValues(value['appUsage']),
          'appWifiUsage': _mapIntValues(value['appWifiUsage']),
          'appMobileUsage': _mapIntValues(value['appMobileUsage']),
        };
      }
    });
  }

  Map<String, int> _mapIntValues(dynamic raw) {
    final values = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        values['$key'] = _int(value);
      });
    }
    return values;
  }

  Map<String, Map<String, dynamic>> get _policyMap {
    final result = <String, Map<String, dynamic>>{};
    final encoded = _prefs?.getString('app_policies');
    if (encoded == null) return result;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) result['$key'] = Map<String, dynamic>.from(value);
        });
      }
    } catch (_) {
      // Ignore a corrupt local policy file and use safe defaults.
    }
    return result;
  }

  void _loadPolicyState(String? encoded) {
    if (encoded == null) return;
    try {
      jsonDecode(encoded);
    } catch (_) {
      // The policies are reconstructed safely from defaults during the next device refresh.
    }
  }

  void _importRules(dynamic raw) {
    if (raw is! List) return;
    final savedRows = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => '${item['id'] ?? ''}'.isNotEmpty)
        .toList();
    if (savedRows.isEmpty) return;
    final existing = {for (final rule in rules) rule.id: rule};
    rules = savedRows.map((saved) {
      final id = '${saved['id']}';
      final base = existing[id];
      if (base != null) {
        return base.copyWith(
            enabled: saved['enabled'] is bool
                ? saved['enabled'] as bool
                : base.enabled);
      }
      return SmartRule(
        id: id,
        title: '${saved['title'] ?? 'قاعدة مستوردة'}',
        description: '${saved['description'] ?? ''}',
        icon: Icons.tune_rounded,
        enabled: saved['enabled'] == true,
        color: AppColors.primary,
      );
    }).toList();
  }

  void _importProfiles(dynamic raw) {
    if (raw is! List) return;
    final savedRows =
        raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item));
    final byId = {for (final row in savedRows) '${row['id']}': row};
    profiles = profiles.map((profile) {
      final saved = byId[profile.id];
      return saved == null
          ? profile
          : profile.copyWith(
              active: saved['active'] is bool
                  ? saved['active'] as bool
                  : profile.active);
    }).toList();
  }

  void _loadRules(String? encoded) {
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        final savedRows =
            decoded.whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
        final existingIds = rules.map((rule) => rule.id).toSet();
        for (final saved in savedRows) {
          final id = '${saved['id'] ?? ''}';
          final title = saved['title'];
          if (!existingIds.contains(id) &&
              title is String &&
              title.trim().isNotEmpty) {
            rules = [
              ...rules,
              SmartRule(
                  id: id,
                  title: title,
                  description: '${saved['description'] ?? ''}',
                  icon: Icons.tune_rounded,
                  enabled: saved['enabled'] == true,
                  color: AppColors.primary)
            ];
          }
        }
        rules = rules.map((rule) {
          final saved = savedRows.firstWhere((item) => item['id'] == rule.id,
              orElse: () => const <dynamic, dynamic>{});
          return rule.copyWith(
              enabled: saved['enabled'] is bool
                  ? saved['enabled'] as bool
                  : rule.enabled);
        }).toList();
      }
    } catch (_) {}
  }

  void _loadProfiles(String? encoded) {
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        profiles = profiles.map((profile) {
          final saved = decoded
              .whereType<Map>()
              .cast<Map<dynamic, dynamic>>()
              .firstWhere((item) => item['id'] == profile.id,
                  orElse: () => const <dynamic, dynamic>{});
          return profile.copyWith(
              active: saved['active'] is bool
                  ? saved['active'] as bool
                  : profile.active);
        }).toList();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', onboardingDone);
    await prefs.setBool('permission_prompt_shown', permissionPromptShown);
    await prefs.setBool('notifications', notificationsEnabled);
    await prefs.setBool('speed_meter_appbar', speedMeterInAppBar);
    await prefs.setBool('speed_service_enabled', speedServiceEnabled);
    await prefs.setBool('limit_monitor_user_enabled', limitMonitoringEnabled);
    final monitorConfigured = limitMonitoringEnabled &&
        rules.any((rule) => rule.id == 'limit' && rule.enabled) &&
        apps.any((app) => app.limitBytes > 0 && app.isRuleEnabled);
    await prefs.setBool('limit_monitor_enabled', monitorConfigured);
    await prefs.setString('app_sort', appSort);
    await prefs.setBool('dark_mode', themeMode == ThemeMode.dark);
    await prefs.setInt('usage_start_millis', usageStart.millisecondsSinceEpoch);
    if (todayResetAt == null) {
      await prefs.remove('today_reset_millis');
      await prefs.remove('today_reset_baseline');
    } else {
      await prefs.setInt(
          'today_reset_millis', todayResetAt!.millisecondsSinceEpoch);
      await prefs.setString(
          'today_reset_baseline',
          jsonEncode({
            'mobileBytes': _todayBaselineMobileBytes,
            'wifiBytes': _todayBaselineWifiBytes,
            'appUsage': _todayBaselineApps,
            'appWifiUsage': _todayBaselineAppWifi,
            'appMobileUsage': _todayBaselineAppMobile,
          }));
    }
    await prefs.setString('day_baselines', jsonEncode(_dayBaselines));
    await prefs.setString(
        'cached_apps', jsonEncode(apps.map((app) => app.toJson()).toList()));
    await prefs.setString('cached_daily_records',
        jsonEncode(dailyRecords.map((record) => record.toJson()).toList()));
    await prefs.setString('cached_device_date',
        _dateLabel(DateTime.now().millisecondsSinceEpoch));
    final policies = <String, dynamic>{
      for (final app in apps)
        app.packageName: {
          'accessMode': app.accessMode.name,
          'isFavorite': app.isFavorite,
          'limitBytes': app.limitBytes,
          'warningPercent': app.warningPercent,
          'isRuleEnabled': app.isRuleEnabled,
          'autoBlocked': app.autoBlocked,
        },
    };
    await prefs.setString('app_policies', jsonEncode(policies));
    await prefs.setString(
        'rules', jsonEncode(rules.map((rule) => rule.toJson()).toList()));
    await prefs.setString(
        'profiles',
        jsonEncode(profiles
            .map((profile) => {'id': profile.id, 'active': profile.active})
            .toList()));
  }

  static int _int(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static int? _intOrNull(dynamic value) => value == null ? null : _int(value);
  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static List<String> _strings(dynamic value) =>
      value is List ? value.map((item) => '$item').toList() : const <String>[];

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _deviceRefreshTimer?.cancel();
    _currentUsageTimer?.cancel();
    super.dispose();
  }
}
