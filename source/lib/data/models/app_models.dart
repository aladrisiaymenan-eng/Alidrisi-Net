import 'dart:typed_data';

import 'package:flutter/material.dart';

enum AccessMode { allowed, blocked, wifiOnly, mobileOnly, backgroundBlocked }

enum RuleAction { notify, cutInternet, cutAndNotify, none }

enum ProfileKind { study, work, saver, custom }

class ManagedApp {
  const ManagedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.icon,
    this.iconBytes,
    required this.usageBytes,
    required this.wifiBytes,
    required this.mobileBytes,
    required this.accessMode,
    required this.isFavorite,
    required this.limitBytes,
    required this.warningPercent,
    required this.isRuleEnabled,
    this.autoBlocked = false,
    this.uid,
    this.isSystemApp = false,
    this.isLaunchable = true,
    this.requestedPermissions = const <String>[],
    this.grantedPermissions = const <String>[],
  });

  final String id;
  final String name;
  final String packageName;
  final IconData icon;
  final Uint8List? iconBytes;
  final int usageBytes;
  final int wifiBytes;
  final int mobileBytes;
  final AccessMode accessMode;
  final bool isFavorite;
  final int limitBytes;
  final int warningPercent;
  final bool isRuleEnabled;
  final bool autoBlocked;
  final int? uid;
  final bool isSystemApp;
  final bool isLaunchable;
  final List<String> requestedPermissions;
  final List<String> grantedPermissions;

  double get progress =>
      limitBytes <= 0 ? 0 : (usageBytes / limitBytes).clamp(0, 1).toDouble();
  bool get nearLimit => limitBytes > 0 && progress >= warningPercent / 100;
  bool get isBlocked => accessMode == AccessMode.blocked;
  bool get hasUsage => usageBytes > 0 || wifiBytes > 0 || mobileBytes > 0;

  ManagedApp copyWith({
    AccessMode? accessMode,
    bool? isFavorite,
    int? limitBytes,
    int? warningPercent,
    bool? isRuleEnabled,
    bool? autoBlocked,
    int? usageBytes,
    int? wifiBytes,
    int? mobileBytes,
  }) =>
      ManagedApp(
        id: id,
        name: name,
        packageName: packageName,
        icon: icon,
        iconBytes: iconBytes,
        usageBytes: usageBytes ?? this.usageBytes,
        wifiBytes: wifiBytes ?? this.wifiBytes,
        mobileBytes: mobileBytes ?? this.mobileBytes,
        accessMode: accessMode ?? this.accessMode,
        isFavorite: isFavorite ?? this.isFavorite,
        limitBytes: limitBytes ?? this.limitBytes,
        warningPercent: warningPercent ?? this.warningPercent,
        isRuleEnabled: isRuleEnabled ?? this.isRuleEnabled,
        autoBlocked: autoBlocked ?? this.autoBlocked,
        uid: uid,
        isSystemApp: isSystemApp,
        isLaunchable: isLaunchable,
        requestedPermissions: requestedPermissions,
        grantedPermissions: grantedPermissions,
      );

  factory ManagedApp.fromJson(Map<String, dynamic> raw) {
    final packageName =
        raw['packageName'] is String ? raw['packageName'] as String : 'unknown';
    final modeName = raw['accessMode'];
    final mode = AccessMode.values.firstWhere((item) => item.name == modeName,
        orElse: () => AccessMode.allowed);
    int asInt(dynamic value, [int fallback = 0]) =>
        value is num ? value.toInt() : fallback;
    return ManagedApp(
      id: raw['id'] is String ? raw['id'] as String : packageName,
      name: raw['name'] is String ? raw['name'] as String : packageName,
      packageName: packageName,
      icon: Icons.apps_rounded,
      usageBytes: asInt(raw['usageBytes']),
      wifiBytes: asInt(raw['wifiBytes']),
      mobileBytes: asInt(raw['mobileBytes']),
      accessMode: mode,
      isFavorite: raw['isFavorite'] == true,
      limitBytes: asInt(raw['limitBytes']),
      warningPercent: asInt(raw['warningPercent'], 80),
      isRuleEnabled: raw['isRuleEnabled'] != false,
      autoBlocked: raw['autoBlocked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'usageBytes': usageBytes,
        'wifiBytes': wifiBytes,
        'mobileBytes': mobileBytes,
        'accessMode': accessMode.name,
        'isFavorite': isFavorite,
        'limitBytes': limitBytes,
        'warningPercent': warningPercent,
        'isRuleEnabled': isRuleEnabled,
        'autoBlocked': autoBlocked,
      };
}

class DailyUsageRecord {
  const DailyUsageRecord({
    required this.dateLabel,
    required this.mobileBytes,
    required this.wifiBytes,
    this.dayStartMillis,
    this.appUsage = const <String, int>{},
    this.appWifiUsage = const <String, int>{},
    this.appMobileUsage = const <String, int>{},
  });

  final String dateLabel;
  final int mobileBytes;
  final int wifiBytes;
  final int? dayStartMillis;

  /// Best-effort package-level usage for this date. Android reports by UID;
  /// shared UIDs are represented by a combined key when packages share one UID.
  final Map<String, int> appUsage;
  final Map<String, int> appWifiUsage;
  final Map<String, int> appMobileUsage;

  int get totalBytes => mobileBytes + wifiBytes;

  DailyUsageRecord copyWith({
    String? dateLabel,
    int? dayStartMillis,
    int? mobileBytes,
    int? wifiBytes,
    Map<String, int>? appUsage,
    Map<String, int>? appWifiUsage,
    Map<String, int>? appMobileUsage,
  }) =>
      DailyUsageRecord(
        dateLabel: dateLabel ?? this.dateLabel,
        dayStartMillis: dayStartMillis ?? this.dayStartMillis,
        mobileBytes: mobileBytes ?? this.mobileBytes,
        wifiBytes: wifiBytes ?? this.wifiBytes,
        appUsage: appUsage ?? this.appUsage,
        appWifiUsage: appWifiUsage ?? this.appWifiUsage,
        appMobileUsage: appMobileUsage ?? this.appMobileUsage,
      );

  Map<String, dynamic> toJson() => {
        'dateLabel': dateLabel,
        'mobileBytes': mobileBytes,
        'wifiBytes': wifiBytes,
        'dayStartMillis': dayStartMillis,
        'appUsage': appUsage,
        'appWifiUsage': appWifiUsage,
        'appMobileUsage': appMobileUsage,
      };
}

class DataPlan {
  const DataPlan({
    required this.totalBytes,
    required this.usedBytes,
    required this.start,
    required this.end,
    required this.type,
  });

  final int totalBytes;
  final int usedBytes;
  final DateTime start;
  final DateTime end;
  final String type;

  int get remainingBytes => (totalBytes - usedBytes).clamp(0, totalBytes);
  double get progress =>
      totalBytes == 0 ? 0 : (usedBytes / totalBytes).clamp(0, 1).toDouble();
  int get daysLeft => end.difference(DateTime.now()).inDays.clamp(0, 9999);
  double get dailyBudget =>
      daysLeft == 0 ? remainingBytes.toDouble() : remainingBytes / daysLeft;

  Map<String, dynamic> toJson() => {
        'totalBytes': totalBytes,
        'usedBytes': usedBytes,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'type': type,
      };
}

class SmartRule {
  const SmartRule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final Color color;

  SmartRule copyWith({bool? enabled}) => SmartRule(
        id: id,
        title: title,
        description: description,
        icon: icon,
        enabled: enabled ?? this.enabled,
        color: color,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'enabled': enabled
      };
}

class AppProfile {
  const AppProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.active,
    required this.appCount,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool active;
  final int appCount;

  AppProfile copyWith({bool? active, int? appCount}) => AppProfile(
        id: id,
        name: name,
        description: description,
        icon: icon,
        color: color,
        active: active ?? this.active,
        appCount: appCount ?? this.appCount,
      );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes ب';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ج.ب';
}

String formatRate(double kbps) {
  if (kbps < 1024) return '${kbps.toStringAsFixed(1)} ك.ب/ث';
  return '${(kbps / 1024).toStringAsFixed(2)} م.ب/ث';
}

String accessModeLabel(AccessMode mode) => switch (mode) {
      AccessMode.allowed => 'مسموح للشبكة',
      AccessMode.blocked => 'حظر كامل',
      AccessMode.wifiOnly => 'Wi‑Fi فقط',
      AccessMode.mobileOnly => 'بيانات الجوال فقط',
      AccessMode.backgroundBlocked => 'حظر الخلفية',
    };
