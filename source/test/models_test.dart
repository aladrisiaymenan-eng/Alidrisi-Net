import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_manager/data/models/app_models.dart';
import 'package:internet_manager/providers/app_state.dart';

void main() {
  test('formats bytes and rates with Arabic units', () {
    expect(formatBytes(0), '0 ب');
    expect(formatBytes(1024), '1.0 ك.ب');
    expect(formatBytes(1024 * 1024), '1.0 م.ب');
    expect(formatRate(512), '512.0 ك.ب/ث');
    expect(formatRate(2048), '2.00 م.ب/ث');
  });

  test('managed app preserves policy and derives limit state', () {
    final app = ManagedApp(
      id: 'uid:10001',
      name: 'Test App',
      packageName: 'com.example.test',
      icon: Icons.apps,
      iconBytes: Uint8List.fromList([1, 2, 3]),
      usageBytes: 90 * 1024,
      wifiBytes: 50 * 1024,
      mobileBytes: 40 * 1024,
      accessMode: AccessMode.allowed,
      isFavorite: false,
      limitBytes: 100 * 1024,
      warningPercent: 80,
      isRuleEnabled: true,
      uid: 10001,
      requestedPermissions: ['android.permission.INTERNET'],
      grantedPermissions: ['android.permission.INTERNET'],
    );

    expect(app.nearLimit, isTrue);
    expect(app.progress, closeTo(.9, .001));
    expect(app.hasUsage, isTrue);
    final encoded = app.toJson();
    expect(encoded['packageName'], 'com.example.test');
    expect(encoded['accessMode'], 'allowed');
    expect(encoded['limitBytes'], 100 * 1024);
    expect(ManagedApp.fromJson(encoded).accessMode, AccessMode.allowed);
  });

  test('daily records and plans expose consistent derived metrics', () {
    const record = DailyUsageRecord(
        dateLabel: 'اليوم',
        dayStartMillis: 1763942400000,
        mobileBytes: 3,
        wifiBytes: 7,
        appUsage: {'com.example.video': 8, 'com.example.chat': 2},
        appWifiUsage: {'com.example.video': 5, 'com.example.chat': 1},
        appMobileUsage: {'com.example.video': 3, 'com.example.chat': 1});
    expect(record.totalBytes, 10);
    expect(record.appUsage['com.example.video'], 8);
    expect(record.appWifiUsage['com.example.video'], 5);
    expect(record.appMobileUsage['com.example.video'], 3);
    expect(record.copyWith(mobileBytes: 1).totalBytes, 8);
    expect(record.toJson()['dayStartMillis'], 1763942400000);
    expect(record.toJson()['appWifiUsage'], isA<Map<String, int>>());

    final plan = DataPlan(
        totalBytes: 100,
        usedBytes: 40,
        start: DateTime(2026, 1, 1),
        end: DateTime.now().add(const Duration(days: 5)),
        type: 'mobile');
    expect(plan.remainingBytes, 60);
    expect(plan.progress, closeTo(.4, .001));
    expect(plan.dailyBudget, greaterThan(0));
  });

  test('period filters and chart rows use real daily records', () {
    final now = DateTime.now();
    String label(DateTime day) =>
        '${day.year}/${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}';
    DailyUsageRecord record(DateTime day, int bytes) => DailyUsageRecord(
          dateLabel: label(day),
          dayStartMillis:
              DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
          mobileBytes: bytes,
          wifiBytes: 0,
        );

    final state = AppState()
      ..dailyRecords = [
        record(now, 10),
        record(now.subtract(const Duration(days: 2)), 20),
        record(now.subtract(const Duration(days: 9)), 40),
      ]
      ..selectedPeriod = 1;
    expect(state.selectedPeriodTotalUsage, 30);
    expect(state.selectedPeriodRecords, hasLength(2));
    expect(state.chartRecords, hasLength(7));
    expect(
        state.chartRecords.where((item) => item.totalBytes == 0), hasLength(5));

    state.selectedPeriod = 2;
    expect(state.selectedPeriodTotalUsage, 70);
    expect(state.chartRecords, hasLength(30));
  });

  test('smart rules serialize their user-facing metadata', () {
    const rule = SmartRule(
        id: 'custom_1',
        title: 'حد الاستخدام',
        description: 'عند تجاوز الحد',
        icon: Icons.tune,
        enabled: true,
        color: Colors.blue);
    expect(rule.toJson(), {
      'id': 'custom_1',
      'title': 'حد الاستخدام',
      'description': 'عند تجاوز الحد',
      'enabled': true
    });
  });
}
