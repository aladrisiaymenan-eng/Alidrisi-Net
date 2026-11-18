import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:internet_manager/data/models/app_models.dart';
import 'package:internet_manager/data/policy_engine.dart';

ManagedApp app({
  required String id,
  required int usage,
  required int limit,
  AccessMode mode = AccessMode.allowed,
  bool autoBlocked = false,
}) {
  return ManagedApp(
    id: id,
    name: id,
    packageName: 'com.example.$id',
    icon: Icons.apps_rounded,
    usageBytes: usage,
    wifiBytes: usage,
    mobileBytes: 0,
    accessMode: mode,
    isFavorite: false,
    limitBytes: limit,
    warningPercent: 80,
    isRuleEnabled: true,
    autoBlocked: autoBlocked,
  );
}

void main() {
  test('auto-blocks an app when real usage reaches its limit', () {
    final result = applyLocalLimitPolicies(
      [app(id: 'over', usage: 1024, limit: 1024)],
      limitRuleEnabled: true,
    );

    expect(result.single.autoBlocked, isTrue);
    expect(result.single.accessMode, AccessMode.blocked);
  });

  test('removes an automatic block when the rule no longer matches', () {
    final result = applyLocalLimitPolicies(
      [app(id: 'under', usage: 100, limit: 1024, autoBlocked: true)],
      limitRuleEnabled: true,
    );

    expect(result.single.autoBlocked, isFalse);
    expect(result.single.accessMode, AccessMode.allowed);
  });

  test('does not override a manual block when no limit is exceeded', () {
    final result = applyLocalLimitPolicies(
      [
        app(
          id: 'manual',
          usage: 100,
          limit: 1024,
          mode: AccessMode.blocked,
        )
      ],
      limitRuleEnabled: true,
    );

    expect(result.single.autoBlocked, isFalse);
    expect(result.single.accessMode, AccessMode.blocked);
  });
}
